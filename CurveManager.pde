// Manages curves and points data

class CurveManager {
  Table table;
  PVector[] points;
  ArrayList<ArrayList<PVector>> curves = new ArrayList<ArrayList<PVector>>();
  // GCode arrayList
  ArrayList<String> curves_gcode = new ArrayList<String>();

  // Constants and parameters
  float D = 2; // Distance threshold to simplify points into one curve
  float d = 20;
  int steps_per_pixel = 34;
  int curveIndex = 0;

  CurveManager() {
    // Initialize with default values
  }

  void loadData(String csvFilename) {
    // Load the CSV file
    table = loadTable(csvFilename, "header");
    if (table == null) {
      println("Failed to load the CSV file.");
      exit();
    }

    // Parse points from the CSV file
    parsePointsFromCSV();
  }

  void parsePointsFromCSV() {
    points = new PVector[table.getRowCount()];
    for (int i = 0; i < table.getRowCount(); i++) {
      float x = table.getFloat(i, "x");
      float y = table.getFloat(i, "y");
      points[i] = new PVector(x, y);
    }
  }

  void calculateCurves() {
    curves.clear();
    ArrayList<PVector> group = new ArrayList<PVector>();
    float accumulatedDistance = 0;
    float angleThreshold = 15; // Angle change threshold in degrees
    Float lastAngle = null;

    for (int i = 1; i < points.length; i++) {
      PVector p0 = points[i - 1];
      PVector p1 = points[i];
      float dist = p0.dist(p1);
      accumulatedDistance += dist;

      float angle = degrees(PVector.sub(p1, p0).heading());

      if (lastAngle == null) {
        lastAngle = angle; // Initialize tracking
      }

      group.add(p0);

      boolean angleExceeded = abs(angle - lastAngle) > angleThreshold;
      boolean distanceExceeded = accumulatedDistance >= D;

      if (angleExceeded && distanceExceeded) {
        group.add(p1);
        curves.add(new ArrayList<PVector>(group));
        group.clear();
        accumulatedDistance = 0;
        lastAngle = angle; // Reset angle tracking
      } else {
        lastAngle = angle;
      }

      if (i == points.length - 1) {
        group.add(p1);
        curves.add(new ArrayList<PVector>(group));
      }
    }
  }

  void calculateGCode() {
    curves_gcode.clear();
    for (ArrayList<PVector> group : curves) {
      PVector[] bezierPoints = curveManager.prepareBezierPoints(group);
      String gcode = bezierToGcode(bezierPoints[0], bezierPoints[1], bezierPoints[2], bezierPoints[3]);
      curves_gcode.add(gcode);
    }
  }
  int calculateSteps(PVector p0, PVector p1, PVector p2, PVector p3) {
    float d0 = PVector.dist(p0, p3);
    float d1 = PVector.dist(p0, p1) + PVector.dist(p1, p2) + PVector.dist(p2, p3);
    float curvature = (d1 - d0) / d0; // Higher values mean more curvature

    int minSteps = 2;
    int maxSteps = 20;
    return int(lerp(minSteps, maxSteps, constrain(curvature, 0, 1)));
  }

  String bezierToGcode(PVector p0, PVector p1, PVector p2, PVector p3) {
    StringBuilder gcode = new StringBuilder("G0 X").append(p0.x).append(" Y").append(p0.y).append("\n");
    PVector prevPoint = p0;
    int steps = calculateSteps(p0, p1, p2, p3);

    for (int i = 1; i <= steps; i++) {
      float t = i / (float) steps;
      PVector p = bezierPoint(p0, p1, p2, p3, t);
      PVector center = calculateArcCenter(prevPoint, p);
      if (center != null) {
        float radius = prevPoint.dist(center);
        boolean clockwise = isClockwise(prevPoint, p, center);
        gcode.append(clockwise ? "G2" : "G3")
          .append(" X").append(p.x).append(" Y").append(p.y)
          .append(" I").append(center.x)
          .append(" J").append(center.y).append("\n");
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

  ArrayList<PVector> getCurrentCurve() {
    return curves.get(curveIndex);
  }

  String getCurrentGCode() {
    return curves_gcode.get(curveIndex);
  }

  void incrementCurveIndex() {
    curveIndex++;
    if (curveIndex >= curves.size()) {
      curveIndex = 0;
      // Optional: adjust distance parameter
      //D += 20;
      //if (D > 300) {
      //        D = 20;
      //}
      //calculateCurves();
    }
  }

  int getCurvesCount() {
    return curves.size();
  }

  float getDistanceThreshold() {
    return D;
  }

  void setDistanceThreshold(float newD) {
    D = newD;
  }
}
