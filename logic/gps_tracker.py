import math

class GPSTracker:
    def __init__(self):
        self.total_distance = 0.0  # in kilometers
        self.last_position = None
        
    def calculate_distance(self, lat1, lon1, lat2, lon2):
        """
        Haversine formula to calculate the distance between two points on the Earth.
        """
        R = 6371.0  # Earth radius in kilometers
        
        d_lat = math.radians(lat2 - lat1)
        d_lon = math.radians(lon2 - lon1)
        
        a = (math.sin(d_lat / 2)**2 + 
             math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * 
             math.sin(d_lon / 2)**2)
        
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        distance = R * c
        return distance

    def update_position(self, lat, lon):
        """
        Updates the current position and adds to total distance.
        Returns total_distance.
        """
        if self.last_position:
            dist = self.calculate_distance(
                self.last_position['lat'], self.last_position['lon'],
                lat, lon
            )
            # Filter out small noise
            if dist > 0.002:
                self.total_distance += dist
                
        self.last_position = {'lat': lat, 'lon': lon}
        return self.total_distance

    def get_pace(self, elapsed_seconds):
        """
        Calculates pace in minutes per km.
        """
        if self.total_distance == 0:
            return 0.0
            
        pace_min_km = (elapsed_seconds / 60) / self.total_distance
        return pace_min_km
