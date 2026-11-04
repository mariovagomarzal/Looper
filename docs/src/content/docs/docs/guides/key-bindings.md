---
title: Key bindings
description: Keys, modifiers, the left and right modifier keys, and keyboard layouts.
---

Key bindings live in the `binding` table of a [mode](/Looper/docs/concepts/modes/):

```toml
[mode.main.binding]
alt-h = 'focus left'
alt-shift-h = 'move left'
cmd-alt-enter = 'exec-and-forget open -a Ghostty'
```

A binding is any number of modifiers and one key, joined with `-`.

## Modifiers

The modifiers `cmd`, `alt`, `ctrl` and `shift` match the key on either side of the keyboard. Prefix them with `l` or `r` to require
one side only: `lcmd`, `rcmd`, `lalt`, `ralt`, `lctrl`, `rctrl`, `lshift`, `rshift`.

```toml
lalt-h = 'focus left'   # left alt only
alt-h = 'focus left'    # either alt
```

When both `alt-h` and `lalt-h` are bound, `lalt-h` wins for the left key.

:::tip[Keyboards where alt types symbols]
On Spanish, German and many other layouts, <kbd>alt</kbd> types characters like `@`, `#` or `[`. Bind Looper to the
left alt (`lalt-…`) and keep the right one for typing.
:::

## Keys

- Letters `a`…`z`, numbers `0`…`9`, `f1`…`f20`.
- Special keys: `minus`, `equal`, `period`, `comma`, `slash`, `backslash`, `quote`, `semicolon`, `backtick`,
  `leftSquareBracket`, `rightSquareBracket`, `space`, `enter`, `esc`, `backspace`, `tab`, `pageUp`, `pageDown`,
  `home`, `end`, `forwardDelete`, `sectionSign`.
- Arrows: `left`, `down`, `up`, `right`.
- Keypad: `keypad0`…`keypad9`, `keypadClear`, `keypadDecimalMark`, `keypadDivide`, `keypadEnter`, `keypadEqual`,
  `keypadMinus`, `keypadMultiply`, `keypadPlus`.

## Keyboard layouts

With the default `key-mapping.preset = 'system'`, single characters follow your keyboard layout: `alt-ñ` is the key that
types `ñ`, and `alt--` the key that types `-`, wherever they are, also after switching layout. A character that no key
types without modifiers (like `?` on most layouts) can't be bound. Key names like `semicolon` are always the physical
positions of a US keyboard.

The `qwerty`, `dvorak` and `colemak` presets make every key a physical position instead:

```toml
key-mapping.preset = 'qwerty'
```

## Holding modifiers

The [radial wheel](/Looper/docs/guides/wheel/) opens while you hold a set of modifiers, and runs its action when you release them.
