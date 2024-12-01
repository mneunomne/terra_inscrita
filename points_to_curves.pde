Table table;
PVector[] points;

import processing.serial.*;

ArrayList<ArrayList<PVector>> curves = new ArrayList<ArrayList<PVector>>();

PVector currentPosition = new PVector(0, 0); // Track the current position


PGraphics pg;
float D = 1000; // Distance threshold to simplify points into one curve
float d = 2;

boolean saveFrames = true;
boolean animation =false;
boolean setByMouse = false;
PImage bg;

// gcode text file
PrintWriter output;

int steps_per_pixel = 68;

Serial port;  // Create object from Serial class

String[] lines;
int lineIndex = 0;

void setup() {
  size(596, 842, P2D); // a4 paper in pixels (72 dpi) 595 x 842
  bg = loadImage("bg.png");
  background(255);
  image(bg, 0, 0, width, height);
  

  output = createWriter("output.gcode");

  // Initialize the PGraphics object
  pg = createGraphics(1000, 1000);

  // Load the CSV file
  table = loadTable("rios_barreiras.csv", "header");

  // monospaced font  
  PFont font = createFont("Courier New", 12);
  
  // Check if the table loaded successfully
  if (table == null) {
    println("Failed to load the CSV file.");
    exit();
  }

  // Parse the points from the CSV file
  points = new PVector[table.getRowCount()];
  for (int i = 0; i < table.getRowCount(); i++) {
    float x = table.getFloat(i, "x"); // Replace 'x' with the actual column name if different
    float y = table.getFloat(i, "y"); // Replace 'y' with the actual column name if different
    points[i] = new PVector(x, y);
  }

  int portIndex = 5;
  print("[MachineController] SerialList: ");
  printArray(Serial.list());
  String portName = Serial.list()[portIndex]; //change the 0 to a 1 or 2 etc. to match your port
  port = new Serial(this, portName, 115200);

  // noLoop();
  calculateCurves();

  drawImage();
}

String bezierToGcode(PVector p0, PVector p1, PVector p2, PVector p3) {
  StringBuilder gcode = new StringBuilder();
  gcode.append("G0 X").append(p0.x).append(" Y").append(p0.y).append("\n"); // Move to start point
  
  // Approximate the Bezier curve with small arcs
  int steps = 50;
  PVector prevPoint = p0;
  for (int i = 1; i <= steps; i++) {
    float t = i / (float) steps;
    PVector p = bezierPoint(p0, p1, p2, p3, t);
    PVector center = calculateArcCenter(prevPoint, p);
    if (center != null) {
      float radius = prevPoint.dist(center);
      boolean clockwise = isClockwise(prevPoint, p, center);
      gcode.append(clockwise ? "G2" : "G3")
          .append(" X" + p.x)
          .append(" Y" + p.y)
          .append(" I" + (center.x - prevPoint.x))
          .append(" J" + (center.y - prevPoint.y))
          .append("\n");
    } else {
      gcode.append("G1 X").append(p.x).append(" Y").append(p.y).append("\r");
    }
    gcode.append("\r");
    prevPoint = p;
  }
  
  return gcode.toString();
}


PVector bezierPoint(PVector p0, PVector p1, PVector p2, PVector p3, float t) {
  float x = bezierPoint(p0.x, p1.x, p2.x, p3.x, t);
  float y = bezierPoint(p0.y, p1.y, p2.y, p3.y, t);
  return new PVector(x, y);
}

float bezierPoint(float a, float b, float c, float d, float t) {
  float t1 = 1.0 - t;
  return t1 * t1 * t1 * a + 3 * t1 * t1 * t * b + 3 * t1 * t * t * c + t * t * t * d;
}

PVector calculateArcCenter(PVector p1, PVector p2) {
  // Simplified calculation for the arc center
  // This is a placeholder and should be replaced with a proper arc fitting algorithm
  float midX = (p1.x + p2.x) / 2;
  float midY = (p1.y + p2.y) / 2;
  return new PVector(midX, midY);
}

boolean isClockwise(PVector p1, PVector p2, PVector center) {
  // Determine if the arc is clockwise
  float crossProduct = (p2.x - p1.x) * (center.y - p1.y) - (p2.y - p1.y) * (center.x - p1.x);
  return crossProduct < 0;
}

// Parse G-code to extract X and Y values
void updateCurrentPosition(String gcodeLine) {
  String[] tokens = splitTokens(gcodeLine, " X Y");
  for (int i = 0; i < tokens.length; i++) {
    if (tokens[i].equals("X") && i + 1 < tokens.length) {
      currentPosition.x = float(tokens[i + 1]);
    } else if (tokens[i].equals("Y") && i + 1 < tokens.length) {
      currentPosition.y = float(tokens[i + 1]);
    }
  }
}

void calculateCurves () {
  // clear curves
  curves.clear();

  ArrayList<PVector> group = new ArrayList<PVector>();
  float accumulatedDistance = 0;

  for (int i = 1; i < points.length; i++) {
    PVector p0 = points[i - 1];
    PVector p1 = points[i];
    float dist = p0.dist(p1); // Calculate distance between successive points
    accumulatedDistance += dist;
    group.add(p0);

    if (accumulatedDistance >= D || i == points.length - 1) {
      // Add the last point of the group
      group.add(p1);
      
      // Create a deep copy of the group
      ArrayList<PVector> groupCopy = new ArrayList<PVector>();
      for (PVector p : group) {
        groupCopy.add(new PVector(p.x, p.y));
      }
      curves.add(groupCopy);
      // Reset for the next group
      group.clear();
      accumulatedDistance = 0;
    }
  }
}

void drawImage () {
  image(bg, 0, 0, width, height);
  // Draw the path on the PGraphics object
  pg.beginDraw();
  pg.background(255, 0);
  pg.strokeWeight(1);
  pg.noFill();
  int index = 0; 
  for(ArrayList<PVector> group : curves) {
    pg.stroke(0);
    pg.fill(0);
    pg.textSize(18);
    pg.text(index, group.get(0).x, group.get(0).y);
    pg.noFill();
    index++;
    if (group.size() == 2) {
      // Draw straight line
      pg.stroke(0);
      pg.strokeWeight(1);
      pg.line(group.get(0).x, group.get(0).y, group.get(1).x, group.get(1).y);
    }
    if (group.size() > 2) {
      // Use the first and last points as anchors
      PVector p0 = group.get(0);
      PVector p3 = group.get(group.size() - 1);

      // Calculate control points as the average positions of intermediate points
      PVector p1 = group.get(floor(group.size() / 3));
      PVector p2 = group.get(floor(2 * group.size() / 3));


      pg.beginShape();
      pg.strokeWeight(1);
      pg.vertex(p0.x, p0.y);
      pg.bezierVertex(p1.x, p1.y, p2.x, p2.y, p3.x, p3.y);
      pg.endShape();
    }
  }


  if (setByMouse) D= mouseY;
  // display lines_count
  pg.fill(0);
  pg.stroke(0);
  pg.textSize(20);
  pg.text("curves: " + curves.size(), 40, 60);
  pg.text("distance: " + D, 40, 80);

  pg.filter(BLUR, 1.1);

  pg.endDraw();

  // Display the PGraphics object scaled to the screen
  image(pg, 0, (height-width) /2, width, width);
  
  if (animation) {
    D+=d;
    if (d > 0) {
      d = d * 1.005;
    } else {
      d = d - 0.1;
    }
    if(D > 2000) {
      d*=-1;
    }
    if (D < 2) {
      saveFrames = false;
    }
    if (saveFrames) {
      saveFrame("frames/####.png");
    }
  }

  output.flush();  // Writes the remaining data to the file
  output.close();  // Finishes the file
}

void draw () {
  listenToPort();
  stroke(255, 0, 0);
  noFill();
  ellipse(currentPosition.x, currentPosition.y, 10, 10);
}
  

void listenToPort () {
  // read from serial port
  if (port.available() > 0) {
    String inBuffer = port.readStringUntil('\n');
    if (inBuffer != null) {
      // println("[MachineController] Received: " + inBuffer);
      if (inBuffer.contains("OK")) {
        // send next line
        //sendS();
        lineIndex++;
        if (lineIndex >= lines.length) {
          curveIndex++;
          lineIndex = 0;
        }
        sendLine();
      }
    }
  }
}

void sendLine () {
  // get first group from curves
  ArrayList<PVector> group = curves.get(curveIndex);
  PVector p0 = new PVector(group.get(0).x, group.get(0).y);
  PVector p3 = new PVector(group.get(group.size() - 1).x, group.get(group.size() - 1).y);
  PVector p1 = new PVector(group.get(floor(group.size() / 3)).x, group.get(floor(group.size() / 3)).y);
  PVector p2 = new PVector(group.get(floor(2 * group.size() / 3)).x, group.get(floor(2 * group.size() / 3)).y);
  p0.x = -p0.x * steps_per_pixel;
  p0.y = p0.y * steps_per_pixel;
  p1.x = -p1.x * steps_per_pixel;
  p1.y = p1.y * steps_per_pixel;
  p2.x = -p2.x * steps_per_pixel;
  p2.y = p2.y * steps_per_pixel;
  p3.x = -p3.x * steps_per_pixel;
  p3.y = p3.y * steps_per_pixel;
  String gcode = bezierToGcode(p0, p1, p2, p3);
  // split gcode by lines
  lines = split(gcode, '\n');
  String message = lines[lineIndex];
  if (message.contains("G")) {
    // display current position on screen
    updateCurrentPosition(message); // Parse and update the position
    port.write(message + "\n");
  }
  println("GCODE: " + message);
  lineIndex++;
  if (lineIndex >= lines.length) {
    lineIndex = 0;
  }

  //port.write(gcode);
}

int curveIndex = 0;
void keyPressed () {
  if (key == 'a') {
    sendLine();
    curveIndex++;
    if (curveIndex >= curves.size()) {
      curveIndex = 0;
    }
  }


  if (key == 's') {
    sendS();
  }
}