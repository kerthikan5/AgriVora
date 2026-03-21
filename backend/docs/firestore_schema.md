# Firestore Schema — Scan History

## Collection: scans

Each document represents a single soil scan performed by a user.

### Document Structure

{
  "userId": "string",
  "timestamp": "ISO-8601 string",
  "gps": {
    "lat": number,
    "lon": number
  },
  "ph": number,

  "imageUrl": "string",

  "soilSummary": {
    "sand": number,
    "clay": number,
    "organicCarbon": number
  },

  "weatherSummary": {
    "temperature": number,
    "rainfall": number,
    "humidity": number
  },

  "texture": "string",
  "confidence": number,

  "recommendations": [
    {
      "crop": "string",
      "score": number,
      "reasons": ["string"],
      "tips": ["string"]
    }
  ]
}
