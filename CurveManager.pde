// Manages curves and points data

class CurveManager {
  Table table;
  PVector[] points;
  ArrayList<ArrayList<PVector>> curves = new ArrayList<ArrayList<PVector>>();
  
  // Constants and parameters
  float D = 0; // Distance threshold to simplify points into one curve
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
  
  void incrementCurveIndex() {
    curveIndex++;
    if (curveIndex >= curves.size()) {
      curveIndex = 0;
      
      // Optional: adjust distance parameter
      //D += 20;
      //if (D > 300) {
      //        D = 20;
      //}
      calculateCurves();
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