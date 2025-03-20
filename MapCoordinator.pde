// Handles map coordinate transformations

class MapCoordinator {
  // Map coordinate boundaries
  float minLat = -22.40520000;
  float maxLat = -22.32638;
  float minLng = -43.10238;
  float maxLng = -43.01716;
  
  MapCoordinator() {
    // Initialize with default values
  }
  
  JSONObject getLatLngFromPos(PVector pos) {
    float lat = map(pos.y - (height - width) / 2, width, 0, minLat, maxLat);
    float lng = map(pos.x, 0, width, minLng, maxLng);
    JSONObject latlng = new JSONObject();
    latlng.setFloat("lat", lat);
    latlng.setFloat("lng", lng);
    return latlng;
  }
  
  // Optional: Add reverse mapping function if needed
  PVector getPosFromLatLng(float lat, float lng) {
    float y = map(lat, minLat, maxLat, width, 0) + (height - width) / 2;
    float x = map(lng, minLng, maxLng, 0, width);
    return new PVector(x, y);
  }
}