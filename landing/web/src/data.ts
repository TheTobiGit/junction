export type Browser = {
  id: string
  name: string
  sub: string
  hue: number // for the dot tint, all anchored to brand tangerine + variations
  short: string
}

export const browsers: Browser[] = [
  { id: 'chrome-work', name: 'Chrome', sub: 'Work', hue: 60, short: 'C' },
  { id: 'chrome-personal', name: 'Chrome', sub: 'Personal', hue: 100, short: 'C' },
  { id: 'arc', name: 'Arc', sub: 'default', hue: 305, short: 'A' },
  { id: 'safari', name: 'Safari', sub: 'default', hue: 230, short: 'S' },
  { id: 'firefox', name: 'Firefox', sub: 'Dev', hue: 35, short: 'F' },
  { id: 'brave', name: 'Brave', sub: 'default', hue: 40, short: 'B' },
]

export type Host = {
  host: string
  path: string
  title: string
  source: string
  to: string // browser id
  priv?: boolean
  at: string // timestamp label
}

export const hosts: Host[] = [
  { host: 'github.com', path: '/TheTobiGit/junction/pull/842', title: 'PR #842 · favorite picker', source: 'Slack', to: 'chrome-work', at: '09:14' },
  { host: 'figma.com', path: '/file/abc/site', title: 'Junction site v3', source: 'Mail', to: 'arc', at: '09:21' },
  { host: 'mail.google.com', path: '/u/1/work', title: 'Q3 invoice · Acme', source: 'Calendar', to: 'chrome-personal', at: '10:02' },
  { host: 'chase.com', path: '/auth/login', title: 'Banking · sign in', source: 'Notes', to: 'safari', priv: true, at: '11:47' },
  { host: 'localhost:3000', path: '/dashboard', title: 'Local dev server', source: 'Terminal', to: 'firefox', at: '13:20' },
  { host: 'news.ycombinator.com', path: '/item?id=42', title: 'Show HN: Junction', source: 'iMessage', to: 'brave', at: '15:08' },
]

export const keymap: { keys: string; label: string }[] = [
  { keys: '1–9', label: 'open in slot' },
  { keys: '↵', label: 'open highlighted' },
  { keys: '⌥', label: 'hold for private' },
  { keys: '␣', label: 'preview URL' },
  { keys: '⌘C', label: 'copy URL' },
  { keys: '?', label: 'cheat sheet' },
  { keys: 'esc', label: 'cancel' },
]
