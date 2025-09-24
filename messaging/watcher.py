import os
import time
from datetime import datetime, timezone
from hvac import Client, exceptions
from dateutil import parser
import pydash

groups = ["IT", "Financial"]


def check_new_messages(client: Client, last_check: datetime):
    for group in groups:
        try:
            response = client.adapter.request(
                "LIST", f"/v1/kv-v2/detailed-metadata/ciphertexts/{group}"
            )
            metadatas = pydash.get(response, "data.key_info", default={})
            for key in metadatas.keys():
                updated_at = parser.isoparse(metadatas[key]["updated_time"])
                sender = pydash.get(
                    metadatas, "custom_metadata.sender", default="unknown"
                )
                if updated_at > last_check:
                    print(f"group={group}, title={key}, sender={sender}")
        except exceptions.InvalidPath:
            continue


def main():
    token = os.getenv("APP_TOKEN")
    if not token:
        print(
            "To use the watcher, provide a token through the APP_TOKEN environment variable"
        )
        return

    client = Client(url="http://localhost:8200", token=token)

    last_check = datetime.now(timezone.utc)

    try:
        while True:
            now = datetime.now(timezone.utc)
            check_new_messages(client, last_check)
            last_check = now
            time.sleep(5)
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
