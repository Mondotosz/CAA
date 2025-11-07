#import "@preview/ilm:1.4.1": *
#import "@preview/gentle-clues:1.2.0": *
#import "@preview/codly:1.3.0": *
#import "@preview/codly-languages:0.1.8": *

#show: ilm.with(
  title: [Rapport Labo 2],
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
      color: rgb("#89caff"),
    ),
  ),
)

#show: codly-init.with()
#codly(languages: codly-languages)

#show link: underline
#show raw: set text(font: "JetBrainsMono NFP")

#let _red(x) = text(
  fill: color.red,
  $#x$,
)

= Code analysis

In this section, we'll go over the global constants and each function in the
order they are called to explain what they do and how/where they are used.

#info(title: "Note", [
  The explanation is mainly given as comments in the code accompanied with the
  addition of typing whenever it makes sense
])

== Global constants

At the start of the scripts, we have multiple constants defined which are the
parameters for the secp256k1

```py
# --- secp256k1 parameters ---
P = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F
A = 0
B = 7
Gx = 55066263022277343669578718895168534326250603453777594175500187360389116729240
Gy = 32670510020758816978083085130507043184471273380659243275938904335757337482424
N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
```

En comparant avec les paramètres que l'on trouve en
ligne#footnote[https://neuromancer.sk/std/secg/secp256k1] on peut confirmer que
ces paramètres sont correctes.

== `main`

This is the entry point of the program.

=== `load_or_generate_keys`

This function is called at the start of `main` with this snippet

```py
    priv, pub = load_or_generate_keys()
```

This is the only time this function is called.

```py
def load_or_generate_keys() -> tuple[int, tuple[int, int]]:
    """This function loads an existing pair of private/public keys or generates,
    saves and return a new pair.
    """

    # Files containing the private and public keys
    priv_file = "ecdsa_private.key"
    pub_file = "ecdsa_public.key"

    if os.path.exists(priv_file) and os.path.exists(pub_file):
        # If both files exist, proceed to extract the private and public keys.
        with open(priv_file, "r") as f:
            # The private key is converted from a base16 string to an int.
            # NOTE: The fact that we strip what we read shouldn't matter unless
            # the key isn't stored properly
            priv = int(f.read().strip(), 16)
        with open(pub_file, "r") as f:
            # The public key is read as a JSON object with the keys x and y
            # containing integers in base64
            pub_data = json.load(f)
            pub = (int(pub_data["x"], 16), int(pub_data["y"], 16))
        print("Loaded existing keypair from disk.")
    else:
        print("No keypair found — generating new one...")
        # If any of the files do not exist we generate a new pair of keys
        priv, pub = generate_keypair()
        with open(priv_file, "w") as f:
            # The private key is simply written properly in hex format
            f.write(hex(priv))
        with open(pub_file, "w") as f:
            # The public key is saved correctly in JSON
            json.dump({"x": hex(pub[0]), "y": hex(pub[1])}, f)
        print("New keypair generated and saved.")
    return priv, pub
```

In this function we call `generate_keypair` to generate a pair of keys.

==== `generate_keypair`

```py
def generate_keypair() -> tuple[int, tuple[int, int]]:
    """Generate a pair of keys"""
    # Take a random value between 1 and N (N not included)
    priv = random.randrange(1, N)
    # Multiply the private key with G to get the pulic key
    pub = scalar_mult(priv, (Gx, Gy))
    return priv, pub
```

We take a random number between 1 and N for the private key

$
  a in {1,...,N-1}
$

And for the public key, we call `scalar_mult`

===== `scalar_mult`

```py
def scalar_mult(k: int, point: tuple[int, int] | None):
    """Multiply a point on the curve by the scalar value k"""
    # Check that the point is on the curve otherwise the multiplication isn't
    # possible.
    assert is_on_curve(point)
    if k % N == 0 or point is None:
        # If k is perfectly divisible by N or now point was given, the result is None.
        # NOTE: If k is perfectly divisible by N, the result will be a None,
        # this check saves time
        return None
    if k < 0:
        # If k is negative, we simply multiply both inputs by -1 which is
        # simple to do and allows the next part of the algorithm to work.
        return scalar_mult(-k, (point[0], (-point[1]) % P))
    result = None
    addend = point
    # To calculate the result, we add point k times, effectively multiplying
    # the point by k
    while k:
        if k & 1:
            result = point_add(result, addend)
        addend = point_add(addend, addend)
        k >>= 1
    return result
```

This function should work. As a sanity check we can check with sage that the
result is as expected.

```sage
E = EllipticCurve(GF(P), [A,B])
G = E(Gx,Gy)

for i in range(100):
     k = random.randrange(1,N)
     assert(scalar_mult(k, (Gx,Gy)) == (k * G).xy())

for i in range(100):
     k = -random.randrange(1,N)
     assert(scalar_mult(k, (Gx,Gy)) == (k * G).xy())
```

The only difference would be with the case of $k = 0$ since when done
mathematically the result is $cal(O)$ but since the program uses points with $x$
and $y$ coordinates it cannot represent this value. The choice of using `None`
is valid but not that explicit. (Does every `None` represent $cal(O)$ or is it
an invalid value?)

====== `is_on_curve`

```py
def is_on_curve(point: tuple[int, int]):
    """Check if a point is on the Elliptic curve"""
    if point is None:
        return True
    x, y = point
    # Weistrass curve y^2 = x^3 + ax + b
    # NOTE: This is mathematically sound
    return (y * y - (x * x * x + A * x + B)) % P == 0
```

Given $k = (x,y)$ and $x,y in ZZ$, the function properly applies the Weistrass
curve.

$
                y^2 & =x^3+a x+b & space (mod n) \
  y^2 - (x^3+a x+b) & = 0        & space (mod n)
$


= Errors

#task[
  For each error:
  - Show the snippet
  - Explain what the problem is and the implications. What an attacker can do
    and what could go wrong.
  - Explain in simple terms why this should be fixed
  - Give a fix
]

== `random.randrange`

This function is used twice in the code.

#codly(
  highlights: (
    (line: 3, start: 5),
  ),
)
```py
def generate_keypair() -> tuple[int, tuple[int, int]]:
    """Generate a pair of keys"""
    priv = random.randrange(1, N)
    pub = scalar_mult(priv, (Gx, Gy))
    return priv, pub
```

#codly(
  highlights: (
    (line: 4, start: 9),
  ),
)
```
def sign_message(priv, message):
    z = sha256(message)
    while True:
        k = random.randrange(0, N)
        R = scalar_mult(k, (Gx, Gy))
        r = R[0] % N
        if r == 0:
            continue
        k_inv = inv_mod(k, N)
        s = (k_inv * (z + r * priv)) % N
        if s == 0:
            continue
        return (r, s)
```

The documentation#footnote[https://docs.python.org/3/library/random.html] for
the module and its fonction starts with a warning to not use it for security and
cryptographic purposes. This kind of warning shouldn't be ignored since it means
that the prngs it provides are either not proved to be cryptographically secure
or worse, proved to be attackable.

Furthermore, the range can be a problem independently of how good the
distribution is. When multiplying a point with a scalar value, if the value is
equal to zero or a multiple of $N$ the result will be $cal(O)$ which can be
problematic.

For the first usage, the range gives us a value $"priv" in {1,...,N-1}$. This
means that we shouldn't get a `None` but just to be safe we should have an
assertion before returning our keys.

For the second usage, we have $k in {0,...,N-1}$ which means that $R$ can be
`None` which will raise an exception when accessing `R[0]`. This means that that
there is a $1/N$ chance of having an issue when trying to sign a message.

We have two problems here.

=== Bad range ${0,...,N-1}$

The problem here is that there is a chance of raising an exception and the
implications vary depending on how exceptions are handled by the caller as well
as which code paths lead to this function being executed.

The caller shouldn't expect `sign_message` to fail when given valid parameters.
Depending on how they handle exceptions, the program could end up revealing
informations which could be exploited or end up in an unrecoverable state.

If an attacker can trigger this function a lot, it could be used to leak secrets
or for a denial of service attack.

If the exception results in an unrecoverable state such as the program exiting
There is a serious risk of service degradation proportional to the usage.

In simple terms, the risk is that the service becomes unavailable or worse, that
secrets could be leaked and used by bad actors to falsify prescriptions.

The simple fix is to change the range to ${1,...,N-1}$. (Using an assertion as a
sanity check and also allows the typing system to narrow after the
multiplication)

#codly(
  highlights: (
    (line: 4, start: 30, end: 30),
    (line: 6, start: 9),
  ),
)
```py
def sign_message(priv, message):
    z = sha256(message)
    while True:
        k = random.randrange(1, N)
        R = scalar_mult(k, (Gx, Gy))
        assert R
        r = R[0] % N
        if r == 0:
            continue
        k_inv = inv_mod(k, N)
        s = (k_inv * (z + r * priv)) % N
        if s == 0:
            continue
        return (r, s)
```

As stated previously, the range used in `generate_keypair` is correct but we
should still have an assertion after the multiplication since it doesn't cost us
much and having $cal(O)$ as a public key would be catastrophic. (since
$forall k in ZZ, k cal(O) = cal(O)$ )

#codly(
  highlights: (
    (line: 4, start: 5),
  ),
)
```py
def generate_keypair() -> tuple[int, Point]:
    priv = random.randrange(1, N)
    pub = scalar_mult(priv, (Gx, Gy))
    assert pub
    return priv, pub
```

=== Usage of `random.randrange`


#task[
  snippet
]

#task[
  implications
]

#task[
  attacker
]

#task[
  what could go wrong
]

#task[
  simple terms why fix
]

#task[
  fix
]

== `load_or_generate_keys`

=== Blind loading

```py
if os.path.exists(priv_file) and os.path.exists(pub_file):
    # If both files exist, proceed to extract the private and public keys.
    with open(priv_file, "r") as f:
        # The private key is converted from a base16 string to an int.
        # NOTE: The fact that we strip what we read shouldn't matter unless
        # the key isn't stored properly
        priv = int(f.read().strip(), 16)
    with open(pub_file, "r") as f:
        # The public key is read as a JSON object with the keys x and y
        # containing integers in base64
        pub_data = json.load(f)
        pub = (int(pub_data["x"], 16), int(pub_data["y"], 16))
    print("Loaded existing keypair from disk.")
    # WARN: if both files exist, their value is taken as ground truth. There
    #   is no verification that the private key is in [1;N[ and that the
    #   public key is the result of priv * G
```

When loading the pair of keys from disk, there are no checks made to validate
it. The problem is that to be able to properly sign and verify the signature of
a message you need the private key $a$ to respect $1 <= a < N$ and the public
key $A$ should be $A = a G$.

#task[
  implications
]

#task[
  attacker
]

#task[
  what could go wrong
]

#task[
  simple terms why fix
]

#task[
  fix
]

=== Destructive storage of private key

```py
else:
    print("No keypair found — generating new one...")
    # If any of the files do not exist we generate a new pair of keys
    priv, pub = generate_keypair()
    with open(priv_file, "w") as f:
        # The private key is simply written properly in hex format
        f.write(hex(priv))
```

If only private key exists, the function will overwrite it with a new private
key. This is destructive since we can always compute the public key from the
private key but we cannot recover the private key once overwritten.

This means that if for some reasons, the public key isn't found we will get a
new pair of keys. We will need to distribute our new public key to anyone who
needs to verify our signatures and if we can't our old public key anywhere, the
validity of past records becomes unverifiable.

#task[
  attacker
]

#task[
  what could go wrong
]

#task[
  simple terms why fix
]

#task[
  fix
]

=== Insecure permission management of private key

```py
else:
    print("No keypair found — generating new one...")
    # If any of the files do not exist we generate a new pair of keys
    priv, pub = generate_keypair()
    with open(priv_file, "w") as f:
        # The private key is simply written properly in hex format
        f.write(hex(priv))
    with open(pub_file, "w") as f:
        # The public key is saved correctly in JSON
        json.dump({"x": hex(pub[0]), "y": hex(pub[1])}, f)
    print("New keypair generated and saved.")
    # WARN: The public and private keys are both simply saved to disk
    #   without any specifications when it comes to permissions. (on linux,
    #   resulted in 644 permissions)
```

When either a public key or private key file is missing, a new pair of keys is
generated and saved to disk using the built-in open function in `'w'` mode.

The keys will have the default permissions (determined by the OS). On Linux, it
often means `0644` which is an issue since we don't want any other user to be
able to read the private key.

In the event of an attacker gaining access to the host running the program, they
can extract the private key without any privilege escalation. This would allow
them to falsify records. (Breaks authenticity and integrity)

Effectively, this would mean that the attacker could create a fake prescription
and the pharmacy would treat it as valid. For doctors, this would allow the
attacker to create fake symptoms for a patient which in turn would result in
more work for the doctors to check and effectively destroy the efficiency
brought by the system.

This issue should be fixed because it could cause serious legal troubles since
it involves medical prescriptions. Furthermore, it also risks the loss of trust
in the system.

#task[
  fix
]
