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
      if (inBuffer != null && inBuffer.contains("OK")) {
        lineIndex++;
        if (lineIndex >= lines.length) {
          curveManager.incrementCurveIndex();
          lineIndex = 0;
        }
        sendLine();
      }
    }
  }
  
  void sendLine() {
    ArrayList<PVector> group = curveManager.getCurrentCurve();
    PVector[] bezierPoints = curveManager.prepareBezierPoints(group);
    String gcode = bezierToGcode(bezierPoints[0], bezierPoints[1], bezierPoints[2], bezierPoints[3]);
    lines = split(gcode, '\n');
  
    if (lineIndex < lines.length && lines[lineIndex].contains("G")) {
      PVector pos = updateCurrentPosition(lines[lineIndex]);
      port.write(lines[lineIndex] + "\n");
    }
    lineIndex = (lineIndex + 1) % lines.length;
  }
  
  String bezierToGcode(PVector p0, PVector p1, PVector p2, PVector p3) {
    StringBuilder gcode = new StringBuilder("G0 X").append(p0.x).append(" Y").append(p0.y).append("\n");
    PVector prevPoint = p0;
    int steps = 50;
  
    for (int i = 1; i <= steps; i++) {
      float t = i / (float) steps;
      PVector p = bezierPoint(p0, p1, p2, p3, t);
      PVector center = calculateArcCenter(prevPoint, p);
      if (center != null) {
        float radius = prevPoint.dist(center);
        boolean clockwise = isClockwise(prevPoint, p, center);
        gcode.append(clockwise ? "G2" : "G3")
             .append(" X").append(p.x).append(" Y").append(p.y)
             .append(" I").append(center.x - prevPoint.x)
             .append(" J").append(center.y - prevPoint.y).append("\n");
      } else {
        gcode.append("G1 X").append(p.x).append(" Y").append(p.y).append("\n");
      }
      prevPoint = p;
    }
    return gcode.toString();
  }
  
  PVector bezierPoint(PVector p0, PVector p1, PVector p2, PVector p3, float t) {
    float x = bezierPointCalc(p0.x, p1.x, p2.x, p3.x, t);
    float y = bezierPointCalc(p0.y, p1.y, p2.y, p3.y, t);
    return new PVector(x, y);
  }
  
  float bezierPointCalc(float a, float b, float c, float d, float t) {
    float t1 = 1.0 - t;
    return t1 * t1 * t1 * a + 3 * t1 * t1 * t * b + 3 * t1 * t * t * c + t * t * t * d;
  }
  
  PVector calculateArcCenter(PVector p1, PVector p2) {
    float midX = (p1.x + p2.x) / 2;
    float midY = (p1.y + p2.y) / 2;
    return new PVector(midX, midY);
  }
  
  boolean isClockwise(PVector p1, PVector p2, PVector center) {
    float crossProduct = (p2.x - p1.x) * (center.y - p1.y) - (p2.y - p1.y) * (center.x - p1.x);
    return crossProduct < 0;
  }
  
  PVector updateCurrentPosition(String gcodeLine) {
    String[] tokens = splitTokens(gcodeLine, " X Y");
    prevPosition = new PVector(currentPosition.x, currentPosition.y);
    currentPosition.x = ((float(tokens[1]) / curveManager.steps_per_pixel) * -1) / pg.width * width;
    currentPosition.y = (float(tokens[2]) / curveManager.steps_per_pixel) / pg.height * width + (height - width) / 2;
    println("currentPosition", currentPosition.x, currentPosition.y);
    
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