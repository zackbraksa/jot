<p align="center">
  <img src="Assets/MarginJot.icon/Assets/Foreground.png" alt="" width="144" height="144">
</p>
<h1 align="center">Jot</h1>
<p align="center"><strong>One note, right in your Mac menu bar.</strong></p>

Use Jot for a thought you want to keep, a bit of text you need to paste again, or a draft you’ll come back to. Click the menu bar icon to open your note and press <kbd>Esc</kbd> to get back to what you were doing.

Jot saves as you type. Your note stays on your Mac as a plain-text file.

## Build from source

You’ll need macOS 14 or later and Xcode 16 or later.

```sh
git clone https://github.com/zackbraksa/jot.git
cd jot
./script/build_and_run.sh --build-only
open Jot.app
```

To install Jot in `/Applications` and launch it, run the script without `--build-only`.

## License

[MIT](LICENSE)
