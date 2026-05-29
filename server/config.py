from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    hive_api_key: str = ""  # not required until Hive is enabled
    apns_team_id: str
    apns_key_id: str
    apns_private_key_path: str
    apns_bundle_id: str = "com.yourname.reeldetector"
    apns_sandbox: bool = False
    server_host: str = "0.0.0.0"
    server_port: int = 8000
    max_video_mb: int = 50
    hive_frame_count: int = 20

    class Config:
        env_file = ".env"


settings = Settings()
