from pydantic import BaseModel


class AiModelInfo(BaseModel):
    name: str
    version: str
    type: str


class TopPrediction(BaseModel):
    species_id: int | None = None
    scientific_name: str
    common_name: str | None = None
    confidence: float | None = None


class PredictionItem(BaseModel):
    rank: int
    species_id: int | None = None
    scientific_name: str
    common_name: str | None = None
    confidence: float
    model_name: str | None = None
    model_version: str | None = None


class MeasurementEstimate(BaseModel):
    height_m: float | None = None
    canopy_width_m: float | None = None
    dbh_cm: float | None = None
    measurement_method: str
    confidence: float | None = None


class LocationHint(BaseModel):
    latitude: float | None = None
    longitude: float | None = None
    message: str


class ReceivedInput(BaseModel):
    plant_parts: list[str]
    image_count: int


class PredictionDebug(BaseModel):
    class_order: list[str]
    predicted_class_index: int


class MockPredictionData(BaseModel):
    mode: str
    source: str | None = None
    warning: str | None = None
    model: AiModelInfo
    top_prediction: TopPrediction
    predictions: list[PredictionItem]
    explanation: str
    measurement: MeasurementEstimate
    location_hint: LocationHint
    received: ReceivedInput
    debug: PredictionDebug | None = None


class MockPredictionResponse(BaseModel):
    message: str
    data: MockPredictionData
