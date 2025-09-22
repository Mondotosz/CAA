#import "@preview/ilm:1.4.1": *
#import "@preview/gentle-clues:1.2.0": *
#import "@preview/codly:1.3.0": *
#import "@preview/codly-languages:0.1.8": *

#show: ilm.with(
  title: [Rapport Labo 1],
  author: "Kenan Augsburger",
  date: datetime.today(),
  paper-size: "a4",
  date-format: "[day padding:zero] [month repr:long] [year repr:full]",
)

#set page(numbering: "1")
#set text(lang: "fr")

#codly(
  languages: (
    pseudocode: (
      name: "pseudocode",
      icon: text(font: "JetBrainsMono NFP", "ⓟ "),
      color: rgb("#89caff")
    )
  )
)

#show: codly-init.with()
#codly(languages: codly-languages)

#show link: underline
#show raw: set text(font: "JetBrainsMono NFP")

#let _red(x) = text(
  fill: color.red,
  $#x$
)


= Installation and Launch

#question(title: [What are tokens used for and how do they look like in OpenBao? ], [
  Tokens are used to authenticate when accessing the vault. Tokens can be used
  directly or generated dynamically through auth methods. (Using configured
  authentication providers like github OAuth)

  The example provided in the documentation for token formats is the following

  ```text
  b.n6keuKu5Q6pXhaIcfnC9cFNd
  r.JaKnR2AIHNk3fC4SGyyyDVoQ9O
  s.raPGTZdARXdY0KvHcWSpp5wWZIHNT
  ```

  Where each token is prefixed according to their type.
  - `s.`: Service tokens
  - `b.`: Batch tokens
  - `r.`: Recovery tokens

  A token's body is a random `Base62` value of 24 characters.

  #link("https://openbao.org/docs/concepts/tokens/","Tokens documentation")
])

#info(title: "Note", [
  Root tokens are tokens with the `root` policy attached. Those tokens provide
  access to anything within OpenBao and can be set to never expire without any
  renewal required.

  Those tokens are hard to create and should only be used for the initial setup
  or emergencies. They should be revoked otherwise.

  1. The initial root token is generated at `bao operator init` time and has no
     expiration
  2. Root tokens can create other root tokens. Tokens with an expiration cannot
     create a token without expiration.
  3. Using `bao operator generate-root` with permission of a quorum of unseal key
     holders. (Similar to the key ceremony I guess)
])

#info(title: "Environment setup", [
  ```fish
  docker compose up -d
  set -x BAO_ADDR http://localhost:8200
  # Login prompt, use a token when prompted
  bao login
  bao status
  ```
])

#question(title: "How do you set up what are the capabilities of a token?", [
  Capabilities are a property of policies. With policies you can define what
  can be done based on a path. Once you have a policy you can apply the policy
  to a token.

  For example, you can create the policy `Foo`.

  ```hcl
  # file: foo.hcl
  # Allow read of anything within secret/foo
  path "secret/foo/*" {
    capabilities = ["read"]
  }

  # Allow read and update for secret/bar
  path "secret/bar" {
    capabilities = ["read", "update"]
  }
  ```

  ```fish
  bao policy write foo foo.hcl
  ```

  And create a token with the new policy

  ```fish
  bao token create -display-name foo -policy foo
  # Key                  Value
  # ---                  -----
  # token                s.GHmDKZEH0TKGJQ6I5McAvoy9
  # token_accessor       v0EJuFUt81Hy6J7q3YE74xJh
  # token_duration       768h
  # token_renewable      true
  # token_policies       ["default" "foo"]
  # identity_policies    []
  # policies             ["default" "foo"]
  ```

  #link("https://openbao.org/docs/concepts/policies/#policy-syntax", "Policy syntax")
])

#question(title: "What is sealing and unsealing and what is it used for?", [
  Sealing means that the server will throw away the root key it was using to
  decipher the secrets. This means that an intruder cannot extract the key from
  a memory dump but it also means that the service won't be available anymore.

  Unsealing is the process of deciphering the root key. This requires the use
  of unsealing keys which are shared between multiple people using Shamir's
  secret sharing. (Similar to the key ceremony for the root CAs.)

  As stated, the goal of sealing is to ensure that secrets won't leak if signs
  of intrusion are detected.
])

= Main App Description

#question(title: [
  Why isn’t it a great idea to store the ciphertexts on Vault? (We do it to
  avoid having to setup a database).
], [
  The vault's goal is to be a place to securely store secrets. As such it's
  optimized for security before performances. Accessing each message and
  metadata in the vault is done through the http(s) api and it doesn't seem like
  you can read in batch. This means that one message results in one http call
  (which will in turn slow down the vault as the number users/messages grows).

  And more importantly, each message is stored as a ciphertext which means it's
  already encrypted. Storing it in the vault means that there are two layers of
  encryption which increases processing time without any meaningful security
  gains.
])

#info(title: "Quick setup", [
  I created a `fish` script to quickly setup the dev server with the kv and
  transit engines

  ```fish
  ./setup.fish
  ```
])

= Creating Groups

#question(title: [
  What is key rotation and what is it used for?
], [
  A key rotation consists of changing the key used for encryption. Once rotated,
  the old key isn't used to encrypt anymore but it can still be used to decrypt
  ciphertexts that were encrypted with it.

  The rotation is helpful against cryptanalysis as well as potential breaches.
  The likelihood of cryptanalysis to work scales with the number of known
  ciphertexts. By rotating the key we limit the number of ciphertexts which in
  turn reduces the probability of cryptanalysis to work.

  If the key is compromised, at least the affected data is limited to the period
  between key rotations and not the whole database.
])

#question(title: [
  How does Vault make sure one can decrypt an old message when keys are rotated?
], [
  The key is kept. Each ciphertext has metadata attached to it which contains
  all the informations necessary to determine which version (rotation) of the
  key should be used when deciphering
])

#question(title: [
  What do you think of having a key rotation every 1h?
], [
  This seems aggressive. The documentation mentions the NIST rotation guidance
  which tells us that the rotation should happen before a number of encryptions
  have been made with a key. This number of encryptions depends on the algorithm
  of the key but in their example a rotation every 3 month with 40M operations
  per day is sufficient.

  Our application won't come anywhere close to that so having 1h rotation is
  only good to prove that the rotation works but for a production application it
  will just generate a lot of keys which could potentially reduce performances.
])

```hcl
# Financial.hcl
# Allow encryption using the Financial key
path "transit/encrypt/Financial" {
  capabilities = ["update"]
}

# Allow decryption using the Financial key
path "transit/decrypt/Financial" {
  capabilities = ["update"]
}

# Allow read and write access to the Financial store
path "kv-v2/data/ciphertexts/Financial/*" {
  capabilities = ["read", "create"]
}
```

```hcl
# IT.hcl
# Allow encryption using the IT key
path "transit/encrypt/IT" {
  capabilities = ["update"]
}

# Allow decryption using the IT key
path "transit/decrypt/IT" {
  capabilities = ["update"]
}

# Allow read and write access to the IT store
path "kv-v2/data/ciphertexts/IT/*" {
  capabilities = ["read", "create"]
}
```

#question(title: [
  What capabilities did you give for the transit service and why? Provide the
  policy file in your report
], [
  `update`. The policies documentation states `POST` and `PUT`
  methods are used for `create` and `update` as well as the fact that most of
  the project doesn't distinguish between the two and require both.

  When looking at the transit API for encrypt, it's one of the functionalities
  which distinguish between the two. With `update` only, the encryption will
  fail if the key wasn't created. On the other hand, with `create`, the key will
  be generated with default values (for parameters.) Since we want specific
  types for the keys, it's better to only use `update`.
])

#question(title: [
  What capabilities did you give for the kv service and why? Provide the policy
  file in your report.
], [
  `create`, `read` and `list`. The instructions stated that users should be able
  to read and write to the kv (under their respective groups.) Whether they
  should be allowed to `update` or `delete` is ambiguous and will be restricted
  until clarification. The `list` capability is added since the kv will be used
  as the database and the application won't know the keys otherwise.
])
