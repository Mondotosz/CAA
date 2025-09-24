from typing import Callable, Literal
import questionary
from hvac import exceptions, Client
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
        "Title", validate=validate_str_min_len(0)
    ).ask()
    if not title:
        return

    content: str | None = questionary.text(
        "Title", validate=validate_str_min_len(0)
    ).ask()
    if not content:
        return

    ciphertext = client.secrets.transit


def receive(client: Client, group: str):
    title: str | None = questionary.text(
        "Title", validate=validate_str_min_len(0)
    ).ask()
    if not title:
        return


def main():
    client = login()

    if not client:
        return

    group: str | None = questionary.text(
        "Group name", validate=validate_str_min_len(0)
    ).ask()

    if not group:
        return

    choice: Literal["send a message", "receive a message"] | None = questionary.select(
        "What do you want to do?", choices=["send a message", "receive a message"]
    ).ask()

    match choice:
        case "send a message":
            send(client, group)
        case "receive a message":
            receive(client, group)


if __name__ == "__main__":
    main()
