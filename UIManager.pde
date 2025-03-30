// Handles UI rendering and animation

class UIManager {
  PApplet parent;
  CurveManager curveManager;
  
  UIManager(PApplet p, CurveManager cm) {
    parent = p;
    curveManager = cm;
  }
  
  void drawImage() {
    parent.image(bg, 0, 0, width, height);
    pg.beginDraw();
    pg.background(255, 0);
    pg.strokeWeight(1);
    pg.noFill();
  
    int index = 0;
    for (ArrayList<PVector> group : curveManager.curves) {
      renderCurve(index, group);
      index++;
    }
  
    displayCurveStats();
    pg.endDraw();
    //parent.image(pg, 0, (height - width) / 2, width, width);
  
    if (animation) updateAnimation();
  }
  
  void renderCurve(int index, ArrayList<PVector> group) {
    pg.stroke(0);
    pg.fill(0);
    pg.textSize(18);
    // pg.text(index, group.get(0).x, group.get(0).y);  // Uncomment if you want to show curve indices
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
    pg.text("curves: " + curveManager.getCurvesCount(), 40, 60);
    pg.text("distance: " + curveManager.getDistanceThreshold(), 40, 80);
    
    if (setByMouse) {
      curveManager.setDistanceThreshold(mouseY);
    }
  }
  
  void updateAnimation() {
    float D = curveManager.getDistanceThreshold();
    float d = curveManager.d;
    
    D += d;
    d = (d > 0) ? d * 1.005 : d - 0.1;
    if (D > 2000 || D < 2) d *= -1;
    
    curveManager.setDistanceThreshold(D);
    curveManager.d = d;
    
    if (saveFrames) saveFrame("frames/####.png");
  }
}