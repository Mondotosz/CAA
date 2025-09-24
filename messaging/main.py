from typing import Callable, Literal
import questionary
from hvac import exceptions, Client
from base64 import b64encode, b64decode
import sys


def validate_str_min_len(n: int) -> Callable[[str], bool]:
    return lambda x: isinstance(x, str) and len(x) > n


def login() -> Client | None:
    username: str | None = questionary.text(
        "Username", validate=validate_str_min_len(0)
    ).ask()

    if not username:
        return

    password: str | None = questionary.password(
        "Password", validate=validate_str_min_len(0)
    ).ask()

    if not password:
        return

    url: str | None = questionary.text(
        "Vault url", default="http://localhost:8200"
    ).ask()

    if not url:
        return

    client = Client(
        url=url,
    )

    try:
        client.auth.userpass.login(username=username, password=password)
    except exceptions.InvalidRequest as err:
        for e in err.errors if err.errors else ["unknown error"]:
            print(f"Error: {e}")
        return

    return client


def send(client: Client, group: str):
    title: str | None = questionary.text(
        "Title",
        validate=validate_str_min_len(0),
        instruction="(The title is stored as plaintext and acts as an id)",
    ).ask()
    if not title:
        return

    content: str | None = questionary.text(
        "Content", validate=validate_str_min_len(0)
    ).ask()
    if not content:
        return

    response = client.secrets.transit.encrypt_data(
        name=group, plaintext=b64encode(content.encode()).decode("ascii")
    )

    ciphertext: str = response["data"]["ciphertext"]

    client.secrets.kv.v2.create_or_update_secret(
        path=f"ciphertexts/{group}/{title}",
        secret=dict(value=ciphertext),
        mount_point="kv-v2",
    )


def receive(client: Client, group: str):
    response = client.secrets.kv.v2.list_secrets(
        path=f"ciphertexts/{group}", mount_point="kv-v2"
    )

    titles: list[str] = response["data"]["keys"]

    title: str | None = questionary.autocomplete(
        "Title", validate=validate_str_min_len(0), choices=titles
    ).ask()
    if not title:
        return

    try:
        response = client.secrets.kv.v2.read_secret_version(
            path=f"ciphertexts/{group}/{title}",
            mount_point="kv-v2",
            raise_on_deleted_version=False,
        )
    except exceptions.InvalidPath:
        print("Error: message not found")
        return

    ciphertext = response["data"]["data"]["value"]

    response = client.secrets.transit.decrypt_data(name=group, ciphertext=ciphertext)

    plaintext = b64decode(response["data"]["plaintext"].encode()).decode()
    print(plaintext)


def choose_group() -> str:
    group: str | None = questionary.autocomplete(
        "Group name",
        validate=validate_str_min_len(0),
        choices=["IT", "Financial"],
    ).ask()
    if not group:
        sys.exit()

    return group


def main():
    client = login()

    if not client:
        return

    group = choose_group()

    while True:
        choice: (
            Literal["send a message", "receive a message", "change group", "quit"]
            | None
        ) = questionary.select(
            "What do you want to do?",
            choices=["send a message", "receive a message", "change group", "quit"],
        ).ask()

        try:
            match choice:
                case "send a message":
                    send(client, group)
                case "receive a message":
                    receive(client, group)
                case "change group":
                    group = choose_group()
                case _:
                    return
        except exceptions.Forbidden as err:
            for e in err.errors if err.errors else ["unknown error"]:
                print(f"Error: {e}")


if __name__ == "__main__":
    main()
