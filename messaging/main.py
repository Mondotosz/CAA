from typing import Callable, Literal
import questionary
from hvac import exceptions, Client
from base64 import b64encode, b64decode
from typing import cast
from hvac.api.secrets_engines.kv_v2 import KvV2
from pydash import get
import sys


def validate_str_min_len(n: int) -> Callable[[str], bool]:
    return lambda x: isinstance(x, str) and len(x) > n


def login() -> tuple[Client, str] | None:
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

    return (client, username)


def send(client: Client, username: str, group: str):
    title: str | None = questionary.text(
        "Title",
        validate=validate_str_min_len(0),
        instruction="(The title is stored as plaintext and acts as an id)",
    ).ask()
    if not title:
        return

    content: str | None = questionary.text(
        "Content", validate=validate_str_min_len(0), multiline=True
    ).ask()
    if not content:
        return

    response = client.secrets.transit.encrypt_data(
        name=group, plaintext=b64encode(content.encode()).decode("ascii")
    )

    ciphertext: str = get(response, "data.ciphertext")

    client.adapter.request(
        "POST",
        f"/v1/kv-v2/metadata/ciphertexts/{group}/{title}",
        json={"custom_metadata": {"sender": username}},
    )

    cast(KvV2, client.secrets.kv.v2).create_or_update_secret(
        path=f"ciphertexts/{group}/{title}",
        secret=dict(value=ciphertext),
        mount_point="kv-v2",
    )


def receive(client: Client, group: str):
    response = cast(KvV2, client.secrets.kv.v2).list_secrets(
        path=f"ciphertexts/{group}", mount_point="kv-v2"
    )

    titles: list[str] = get(response, "data.keys")

    title: str | None = questionary.autocomplete(
        "Title", validate=validate_str_min_len(0), choices=titles
    ).ask()
    if not title:
        return

    try:
        response = cast(KvV2, client.secrets.kv.v2).read_secret_version(
            path=f"ciphertexts/{group}/{title}",
            mount_point="kv-v2",
            raise_on_deleted_version=False,
        )
    except exceptions.InvalidPath:
        print("Error: message not found")
        return

    ciphertext = get(response, "data.data.value")

    response = client.secrets.transit.decrypt_data(name=group, ciphertext=ciphertext)

    plaintext = b64decode(get(response, "data.plaintext").encode()).decode()
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
    res = login()

    if not res:
        return

    (client, username) = res

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
                    send(client, username, group)
                case "receive a message":
                    receive(client, group)
                case "change group":
                    group = choose_group()
                case _:
                    return
        except exceptions.Forbidden as err:
            for e in err.errors if err.errors else ["unknown error"]:
                print(f"Error: {e}")
            print(err.url)


if __name__ == "__main__":
    main()
