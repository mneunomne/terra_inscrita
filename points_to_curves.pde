// Libraries and global variables
import processing.serial.*;

Table table;
PVector[] points;
PGraphics pg;
PImage bg;

Serial port; // Serial communication object

ArrayList<ArrayList<PVector>> curves = new ArrayList<ArrayList<PVector>>();
PVector prevPosition = new PVector(0, 0); // Track the current position
PVector currentPosition = new PVector(0, 0); // Track the current position

// Constants and parameters
float D = 5; // Distance threshold to simplify points into one curve
float d = 2;
int steps_per_pixel = 68;
int curveIndex = 0;
int lineIndex = 0;

boolean saveFrames = true;
boolean animation = false;
boolean setByMouse = false;

String[] lines;

import websockets.*;

float minLat = -22.40520000; //-22.40732500;
float maxLat = -22.32638; //-22.32425556;
float minLng = -43.10238; //-43.10468333;	
float maxLng = -43.01716; //-43.01486111;

WebsocketServer server;

void setup() {
  // Setup canvas and background
  size(596, 842, P2D); // A4 paper in pixels (72 dpi)

  server = new WebsocketServer(this, 8080, "/");

  bg = loadImage("bg.png");
  background(255);
  image(bg, 0, 0, width, height);

  // Initialize PGraphics object
  pg = createGraphics(1000, 1000);

  // Load the CSV file
  table = loadTable("rios_barreiras.csv", "header");
  if (table == null) {
    println("Failed to load the CSV file.");
    exit();
  }

  // Parse points from the CSV file
  parsePointsFromCSV();

  // Setup serial communication
  initializeSerialCommunication(5);

  // Calculate curves and render the initial image
  calculateCurves();
  drawImage();
}

void draw() {
  listenToPort();
  stroke(0, 0, 0, 125);
  noFill();
  strokeWeight(2);
  if (prevPosition.x != 0 && prevPosition.y != 0) {
    line(prevPosition.x, prevPosition.y, currentPosition.x, currentPosition.y);
  }
}

void keyPressed() {
  if (key == 'a') {
    sendLine();
    curveIndex++;
    if (curveIndex >= curves.size()) curveIndex = 0;
  }
}

// Helper Functions
void parsePointsFromCSV() {
  points = new PVector[table.getRowCount()];
  for (int i = 0; i < table.getRowCount(); i++) {
    float x = table.getFloat(i, "x");
    float y = table.getFloat(i, "y");
    points[i] = new PVector(x, y);
  }
}

void initializeSerialCommunication(int portIndex) {
  println("[MachineController] SerialList: ");
  printArray(Serial.list());
  String portName = Serial.list()[portIndex];
  port = new Serial(this, portName, 115200);
}

void calculateCurves() {
  curves.clear();
  ArrayList<PVector> group = new ArrayList<PVector>();
  float accumulatedDistance = 0;

  for (int i = 1; i < points.length; i++) {
    PVector p0 = points[i - 1];
    PVector p1 = points[i];
    float dist = p0.dist(p1);
    accumulatedDistance += dist;
    group.add(p0);

    if (accumulatedDistance >= D || i == points.length - 1) {
      group.add(p1);
      curves.add(new ArrayList<PVector>(group));
      group.clear();
      accumulatedDistance = 0;
    }
  }
}

void drawImage() {
  image(bg, 0, 0, width, height);
  pg.beginDraw();
  pg.background(255, 0);
  pg.strokeWeight(1);
  pg.noFill();

  int index = 0;
  for (ArrayList<PVector> group : curves) {
    renderCurve(index, group);
    index++;
  }

  displayCurveStats();
  pg.endDraw();
  image(pg, 0, (height - width) / 2, width, width);

  if (animation) updateAnimation();
}

void renderCurve(int index, ArrayList<PVector> group) {
  pg.stroke(0);
  pg.fill(0);
  pg.textSize(18);
  // pg.text(index, group.get(0).x, group.get(0).y);
  pg.noFill();

  if (group.size() == 2) {
    pg.line(group.get(0).x, group.get(0).y, group.get(1).x, group.get(1).y);
  } else if (group.size() > 2) {
    PVector p0 = group.get(0);
    PVector p3 = group.get(group.size() - 1);
    PVector p1 = group.get(floor(group.size() / 3));
    PVector p2 = group.get(floor(2 * group.size() / 3));
    pg.beginShape();
    pg.vertex(p0.x, p0.y);
    pg.bezierVertex(p1.x, p1.y, p2.x, p2.y, p3.x, p3.y);
    pg.endShape();
  }
}

void displayCurveStats() {
  pg.fill(0);
  pg.textSize(20);
  pg.text("curves: " + curves.size(), 40, 60);
  pg.text("distance: " + D, 40, 80);
  if (setByMouse) D = mouseY;
}

void updateAnimation() {
  D += d;
  d = (d > 0) ? d * 1.005 : d - 0.1;
  if (D > 2000 || D < 2) d *= -1;
  if (saveFrames) saveFrame("frames/####.png");
}

JSONObject getLatLngFromPos (PVector pos) {
  float lat = map(pos.y - (height - width) / 2, width, 0, minLat, maxLat);
  float lng = map(pos.x, 0, width, minLng, maxLng);
  JSONObject latlng = new JSONObject();
  latlng.setFloat("lat", lat);
  latlng.setFloat("lng", lng);
  return latlng;
}

// Serial communication and G-code generation
void listenToPort() {
  if (port.available() > 0) {
    String inBuffer = port.readStringUntil('\n');
    if (inBuffer != null && inBuffer.contains("OK")) {
      lineIndex++;
      if (lineIndex >= lines.length) {
        curveIndex++;
        if (curveIndex >= curves.size()) {
          curveIndex = 0;
          lineIndex = 0;
          D += 50;
          calculateCurves();
          drawImage();
        }
        lineIndex = 0;
      }
      sendLine();
    }
  }
}

void sendLine() {
  ArrayList<PVector> group = curves.get(curveIndex);
  PVector[] bezierPoints = prepareBezierPoints(group);
  String gcode = bezierToGcode(bezierPoints[0], bezierPoints[1], bezierPoints[2], bezierPoints[3]);
  lines = split(gcode, '\n');

  if (lines[lineIndex].contains("G")) {
    PVector pos = updateCurrentPosition(lines[lineIndex]);
    //ellipse(pos.x, pos.y, 5, 5);
    port.write(lines[lineIndex] + "\n");
  }
  lineIndex = (lineIndex + 1) % lines.length;
}

PVector[] prepareBezierPoints(ArrayList<PVector> group) {
  PVector[] bezierPoints = new PVector[4];
  bezierPoints[0] = scalePoint(group.get(0));
  bezierPoints[3] = scalePoint(group.get(group.size() - 1));
  bezierPoints[1] = scalePoint(group.get(floor(group.size() / 3)));
  bezierPoints[2] = scalePoint(group.get(floor(2 * group.size() / 3)));
  return bezierPoints;
}

PVector scalePoint(PVector p) {
  return new PVector(-p.x * steps_per_pixel, p.y * steps_per_pixel);
}

// G-code utilities
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
  float x = bezierPoint(p0.x, p1.x, p2.x, p3.x, t);
  float y = bezierPoint(p0.y, p1.y, p2.y, p3.y, t);
  return new PVector(x, y);
}

float bezierPoint(float a, float b, float c, float d, float t) {
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
  currentPosition.x = ((float(tokens[1]) / steps_per_pixel) * -1) / pg.width * width;
  currentPosition.y = (float(tokens[2]) / steps_per_pixel) / pg.height * width + (height - width) / 2;
  println("currentPosition", currentPosition.x, currentPosition.y);
  server.sendMessage(getLatLngFromPos(currentPosition).toString());  
  return currentPosition;
}
