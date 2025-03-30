// Handles serial communication with the machine

class SerialController {
  Serial port;
  WebsocketServer server;
  PApplet parent;
  CurveManager curveManager;
  
  String[] lines;
  int lineIndex = 0;
  
  PVector prevPosition = new PVector(0, 0);
  PVector currentPosition = new PVector(0, 0);
  
  SerialController(PApplet p, int portIndex, CurveManager cm) {
    parent = p;
    curveManager = cm;
    initializeSerialCommunication(portIndex);
  }
  
  void initializeSerialCommunication(int portIndex) {
    println("[MachineController] SerialList: ");
    printArray(Serial.list());
    String portName = Serial.list()[portIndex];
    port = new Serial(parent, portName, 115200);
  }
  
  void setWebsocketServer(WebsocketServer ws) {
    server = ws;
  }
  
  void listenToPort() {
    if (port.available() > 0) {
      String inBuffer = port.readStringUntil('\n');
      if (inBuffer != null){
        println("inBuffer: " + inBuffer);
        if (inBuffer.contains("OK")) {
          sendLine();
        }
        if (inBuffer.contains("r")) {
            // start
            serialController.sendLine();
            curveManager.incrementCurveIndex();
        }
      }
    }
  }
  
  void sendLine() {
    String gcode = curveManager.getCurrentGCode();
    lines = split(gcode, '\n');
    if (lineIndex >= lines.length || !lines[lineIndex].contains("G")) {
      lineIndex = 0;
      curveManager.incrementCurveIndex();
      gcode = curveManager.getCurrentGCode();
    }
    lines = split(gcode, '\n');
    println("[MachineController] Sending line " + lines[lineIndex]);
    PVector pos = updateCurrentPosition(lines[lineIndex]);
    port.write(lines[lineIndex] + "\n");
    lineIndex++;
    //lineIndex = (lineIndex + 1) % lines.length;
  }
  
  PVector updateCurrentPosition(String gcodeLine) {
    String[] tokens = splitTokens(gcodeLine, " X Y");
    prevPosition = new PVector(currentPosition.x, currentPosition.y);
    currentPosition.x = ((float(tokens[1]) / curveManager.steps_per_pixel) * -1) / pg.width * width;
    currentPosition.y = (float(tokens[2]) / curveManager.steps_per_pixel) / pg.height * width + (height - width) / 2;
    //println("currentPosition", currentPosition.x, currentPosition.y);
    
    if (server != null) {
      JSONObject latlng = mapCoordinator.getLatLngFromPos(currentPosition);
      server.sendMessage(latlng.toString());
    }
    
    return currentPosition;
  }
  
  PVector getPrevPosition() {
    return prevPosition;
  }
  
  PVector getCurrentPosition() {
    return currentPosition;
  }
}
