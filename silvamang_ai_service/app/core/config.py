from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "SILVAMANG AI Service"
    app_env: str = "local"
    app_debug: bool = True
    service_host: str = "127.0.0.1"
    service_port: int = 9000
    model_mode: str = "mock"
    mock_model_version: str = "0.1.0"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()

