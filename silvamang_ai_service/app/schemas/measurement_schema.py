from pydantic import BaseModel


class ReferenceObject(BaseModel):
    height_m: float | None = None
    distance_m: float | None = None


class MeasurementResponseData(BaseModel):
    mode: str
    source: str
    height_m: float | None = None
    canopy_width_m: float | None = None
    dbh_cm: float | None = None
    measurement_method: str
    confidence: float
    reference_object: ReferenceObject
    image_count: int
    warning: str | None = None
    message: str


class MeasurementResponse(BaseModel):
    message: str
    data: MeasurementResponseData
