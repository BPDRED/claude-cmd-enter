# ClaudeCmdEnter

A very small helper for the Claude desktop app on Mac.

| You press | What happens in Claude |
|---|---|
| **Enter** | new line |
| **Cmd + Enter** | send the message |
| Shift + Enter | new line (same as before) |

It works only inside Claude. In every other app, Enter works as usual.

Tip: because Cmd+Enter becomes a "real" Enter, use **Cmd+Enter** anywhere in
Claude where you need a normal Enter (for example to confirm a dialog).

## What is in this folder

| File | What it is |
|---|---|
| `main.swift` | The whole program (about 220 lines, with comments) |
| `Info.plist` | The app's name and settings (no Dock icon) |
| `build.sh` | Builds the app for Intel and Apple Silicon Macs |
| `install.sh` | Builds, installs, and makes it start at login |
| `uninstall.sh` | Removes it |

## Install

You need Apple's Command Line Tools (free). If you do not have them, run
`xcode-select --install` in Terminal first. Full Xcode is not needed.

### The easy way

Open Terminal, go to this folder, and run:

```bash
./install.sh
```

Then do the **Permission** step below.

### The manual way, step by step

1. **Build.** This creates `build/ClaudeCmdEnter.app`.

   ```bash
   ./build.sh
   ```

   The last lines must say `x86_64 arm64`. That means it runs on both Intel
   and Apple Silicon Macs.

2. **Copy the app** to the Applications folder inside your home folder.

   ```bash
   mkdir -p ~/Applications && cp -R build/ClaudeCmdEnter.app ~/Applications/
   ```

3. **Start at login.** `install.sh` writes a small text file here:
   `~/Library/LaunchAgents/local.claudecmdenter.plist`.
   It tells macOS: "start this program when I log in". The easiest way to
   create it is to run `./install.sh` (it does steps 1 to 4 for you).
   You can open the file with TextEdit to read it.

4. **Start it now.**

   ```bash
   launchctl bootstrap gui/$UID ~/Library/LaunchAgents/local.claudecmdenter.plist
   ```

5. **Permission.** See the next section.

### Why a LaunchAgent file (and not Apple's newer "SMAppService")

- It is one small text file that you can read and delete yourself.
- It works on macOS 12 and newer (SMAppService needs macOS 13).
- It does not depend on the app's signature, so it keeps working after a rebuild.

macOS may show a notification: *"Background Items Added – ClaudeCmdEnter"*.
This is normal. It is this start-at-login file.

## Permission (you must do this once)

macOS does not allow any program to change key presses without your OK.

1. Open **System Settings → Privacy & Security → Accessibility**.
2. Find **ClaudeCmdEnter** in the list and turn its switch **ON**.
   macOS asks for your Mac password or Touch ID.
3. If ClaudeCmdEnter is not in the list: click **+**, press **Cmd+Shift+G**,
   type `~/Applications`, choose **ClaudeCmdEnter**, click **Open**.

That is the only permission. **Input Monitoring is not needed.**
The helper notices the permission after about 2 seconds. No restart needed.

**After a rebuild:** each build has a new signature, and macOS then treats the
app as a new program. The switch can still look ON but no longer work. Fix:
select ClaudeCmdEnter in the Accessibility list, click **–** to remove it,
then add it again (step 3) and turn it ON.

## The menu bar item

The item appears only while Claude is open. It goes away when you quit Claude.

| You see | Meaning |
|---|---|
| `⌘↩` | On and working |
| `⌘↩ off` (grey) | Off. Enter works normally in Claude |
| `⌘↩ ⚠︎` | On, but the Accessibility permission is missing |

Click it to open the menu:

- **On / Off** – click to switch. Your choice is remembered.
- **Accessibility permission: …** – shows if the permission is granted.
- **Open Accessibility Settings…** – opens the right page in System Settings.
- **Quit ClaudeCmdEnter** – stops the helper until your next login.

When it is **Off**, the helper has no keyboard access at all.

## What the app can and cannot see

While Claude is running and the swap is On, macOS gives the helper every key
press, in any app. This is how macOS works: a helper cannot ask for "only
Enter" or "only Claude". So here is exactly what the code does with it:

- It checks one thing: *is this key Return/Enter, and is Claude in front?*
- If not, the key passes through unchanged. It is not read further, not saved,
  not written to a log.
- If yes, it adds Shift (new line) or removes Cmd (send). Nothing else.

What it does **not** do:

- No network: there is no network code in the program.
- No key logging: no key is ever stored or printed.
- No files: it saves only one setting, On or Off.
- It does not change `Claude.app`.
- It has no keyboard access when Claude is closed, or when the swap is Off.
- It cannot see passwords: macOS hides password fields from programs like this.

You can check all of this yourself: everything is in `main.swift`.

The helper writes a few status lines to the macOS system log, such as
"keyboard hook started". They never contain keys.

## Uninstall

```bash
./uninstall.sh
```

This stops the helper and deletes the app and the start-at-login file.
Nothing else is touched.

Optional clean-up:

- In System Settings → Privacy & Security → Accessibility, select
  **ClaudeCmdEnter** and click **–**. Or run:

  ```bash
  tccutil reset Accessibility local.claudecmdenter
  ```

- To delete the saved On/Off setting:

  ```bash
  defaults delete local.claudecmdenter
  ```

## Troubleshooting

**The permission is ON but nothing happens (or the icon shows `⌘↩ ⚠︎`).**
Remove ClaudeCmdEnter from the Accessibility list with **–**, add it again
with **+** (see Permission, step 3), and turn it ON. This is usually needed
after a rebuild.

**There is no menu bar item.**
The item shows only while Claude is open. If Claude is open and you still do
not see it, the helper is not running (maybe you chose Quit). Start it:

```bash
launchctl kickstart gui/$UID/local.claudecmdenter
```

On a MacBook with a notch, a full menu bar can also hide items. Close some
other menu bar apps to check.

**Enter does nothing in a Claude dialog or button.**
Press **Cmd+Enter** there (it arrives as a normal Enter), or switch the swap Off.

**I want to remove the permission.**
First choose **Off** or **Quit** in the menu, then remove it in System Settings.

**Is it running?**

```bash
launchctl print gui/$UID/local.claudecmdenter | grep state
```

`state = running` means yes.

**See the helper's status messages** (they never contain keys):

```bash
log show --last 10m --predicate 'process == "ClaudeCmdEnter"'
```
