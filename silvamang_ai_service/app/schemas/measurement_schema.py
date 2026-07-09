from pydantic import BaseModel


class MeasurementResponseData(BaseModel):
    mode: str
    height_m: float | None = None
    canopy_width_m: float | None = None
    dbh_cm: float | None = None
    measurement_method: str
    confidence: float
    message: str


class MeasurementResponse(BaseModel):
    message: str
    data: MeasurementResponseData

