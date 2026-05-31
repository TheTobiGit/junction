import { useEffect, useRef, useState, createContext, useContext } from 'react'
import { Dialog } from '@base-ui/react/dialog'
import { motion, useScroll, useTransform, useReducedMotion } from 'motion/react'
import { browsers, hosts, keymap } from './data'

/* ---------------- picker context ---------------- */

type PickerState = { url: string; host: string; priv: boolean } | null
const PickerCtx = createContext<{
  open: (s: NonNullable<PickerState>) => void
  close: () => void
}>({ open: () => {}, close: () => {} })

function PickerProvider({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState<PickerState>(null)
  const [sel, setSel] = useState(0)
  const [priv, setPriv] = useState(false)

  useEffect(() => {
    if (!state) return
    setSel(0)
    setPriv(state.priv)

    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') { setState(null); return }
      if (e.key === 'Alt') { setPriv(true); return }
      if (/^[1-9]$/.test(e.key)) {
        const i = parseInt(e.key) - 1
        if (i < browsers.length) { setSel(i); setTimeout(() => setState(null), 220) }
        return
      }
      if (e.key === 'ArrowDown') { setSel(s => (s + 1) % browsers.length); return }
      if (e.key === 'ArrowUp') { setSel(s => (s - 1 + browsers.length) % browsers.length); return }
      if (e.key === 'Enter') { setState(null); return }
    }
    const onUp = (e: KeyboardEvent) => { if (e.key === 'Alt') setPriv(false) }
    window.addEventListener('keydown', onKey)
    window.addEventListener('keyup', onUp)
    return () => { window.removeEventListener('keydown', onKey); window.removeEventListener('keyup', onUp) }
  }, [state])

  return (
    <PickerCtx.Provider value={{ open: setState, close: () => setState(null) }}>
      {children}
      <Dialog.Root open={!!state} onOpenChange={(v: boolean) => !v && setState(null)}>
        <Dialog.Portal>
          <Dialog.Backdrop className="fixed inset-0 z-[80] bg-[oklch(8%_0_0/.45)] backdrop-blur-md data-[starting-style]:opacity-0 transition-opacity duration-200" />
          <Dialog.Popup
            className={
              'fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 z-[81] w-[min(560px,92vw)] outline-none ' +
              'rounded-[14px] border bg-paper shadow-[0_30px_80px_-10px_oklch(0%_0_0_/_.35),inset_0_1px_0_oklch(100%_0_0_/_.04)] ' +
              'data-[starting-style]:opacity-0 data-[starting-style]:scale-[.98] data-[starting-style]:translate-y-[-46%] transition-[opacity,transform] duration-300 ease-[var(--ease-out-expo)]'
            }
            style={{ borderColor: priv ? 'color-mix(in oklch, var(--color-priv) 50%, var(--color-rule))' : 'var(--color-rule)' }}
          >
            {state && (
              <PickerInner
                url={state.url}
                host={state.host}
                sel={sel}
                priv={priv}
                onPick={(i) => { setSel(i); setTimeout(() => setState(null), 220) }}
              />
            )}
          </Dialog.Popup>
        </Dialog.Portal>
      </Dialog.Root>
    </PickerCtx.Provider>
  )
}

export function usePicker() { return useContext(PickerCtx) }

function PickerInner({
  url,
  sel,
  priv,
  onPick,
}: {
  url: string
  host: string
  sel: number
  priv: boolean
  onPick: (i: number) => void
}) {
  const u = new URL(url)
  return (
    <div className="p-4">
      <div className="flex items-center justify-between gap-3 px-2 pb-3 border-b border-rule">
        <div className="font-mono text-[13px] truncate max-w-[420px]">
          <span className="text-ink-dim">https://</span>
          <span>{u.hostname}</span>
          <span className="text-ink-dim">{u.pathname + u.search}</span>
        </div>
        <span
          className="font-mono text-[10px] uppercase tracking-[0.12em]"
          style={{ color: priv ? 'var(--color-priv)' : 'var(--color-ink-dim)' }}
        >
          {priv ? 'private · ⌥' : 'picker'}
        </span>
      </div>
      <div className="mt-3 flex flex-col gap-1">
        {browsers.map((b, i) => {
          const on = i === sel
          return (
            <button
              key={b.id}
              onClick={() => onPick(i)}
              className={
                'grid grid-cols-[28px_24px_1fr_auto] items-center gap-3 rounded-[10px] px-3 py-2.5 text-left ' +
                'border transition-colors duration-200 ' +
                (on
                  ? priv
                    ? 'border-[color-mix(in_oklch,var(--color-priv)_45%,transparent)] bg-[color-mix(in_oklch,var(--color-paper-2)_88%,var(--color-priv)_10%)]'
                    : 'border-[color-mix(in_oklch,var(--color-tang)_50%,transparent)] bg-[color-mix(in_oklch,var(--color-paper-2)_88%,var(--color-tang)_10%)]'
                  : 'border-transparent hover:bg-paper-2/60')
              }
            >
              <span className="font-mono text-[12px] text-ink-dim">{i + 1}</span>
              <span
                className="grid h-[22px] w-[22px] place-items-center rounded-[6px] text-[11px] font-bold text-paper"
                style={{ background: `oklch(58% 0.18 ${b.hue})` }}
              >
                {b.short}
              </span>
              <span>
                <b className="font-medium">{b.name}</b>
                <small className="block font-mono text-[11px] text-ink-dim">{b.sub}</small>
              </span>
              <span
                className="font-mono text-[10px] uppercase tracking-[0.06em]"
                style={{ color: priv ? 'var(--color-priv)' : 'var(--color-ink-dim)' }}
              >
                {priv ? 'private window' : 'profile'}
              </span>
            </button>
          )
        })}
      </div>
      <div className="mt-3 flex justify-between border-t border-rule pt-3 font-mono text-[11px] text-ink-dim">
        <span>
          <span className="kbd">1</span>–<span className="kbd">9</span> open · <span className="kbd">⌥</span> private · <span className="kbd">esc</span> cancel
        </span>
      </div>
    </div>
  )
}

/* ---------------- shared bits ---------------- */

function LogoMark({ size = 22 }: { size?: number }) {
  return (
    <span
      className="relative grid place-items-center rounded-full bg-ink"
      style={{ width: size, height: size }}
    >
      <span className="absolute inset-[28%] rounded-full bg-tang" />
    </span>
  )
}

function Nav() {
  return (
    <nav className="fixed top-0 left-0 right-0 z-50 flex items-center justify-between px-6 py-5 mix-blend-multiply pointer-events-none">
      <a href="/" className="pointer-events-auto flex items-center gap-2.5 text-[15px] font-medium">
        <LogoMark />
        <span className="font-display text-[20px] tracking-[0.02em]">Junction</span>
      </a>
      <a
        href="https://github.com/TheTobiGit/junction"
        className="pointer-events-auto font-mono text-[12px] uppercase tracking-[0.16em] flex items-center gap-2 hover:text-tang-deep transition-colors"
      >
        <span className="hidden sm:inline">github</span>
        <span aria-hidden>★</span>
      </a>
    </nav>
  )
}

/* ---------------- act 1: hero (typography left · loop right) ---------------- */

function HeroLoopAside() {
  const reduced = useReducedMotion()
  return (
    <div className="relative w-full">
      {/* the rendered loop, the visual that holds the visitor still */}
      <div className="relative w-full aspect-square max-w-[min(560px,90vw)] mx-auto">
        {reduced ? (
          <img
            src="/hero-poster.jpg"
            alt="Junction routes inbound links to the right destination"
            className="w-full h-full object-contain"
          />
        ) : (
          <video
            src="/hero.mp4"
            poster="/hero-poster.jpg"
            autoPlay
            muted
            loop
            playsInline
            preload="auto"
            aria-label="Junction routes inbound links to the right destination"
            className="w-full h-full object-contain"
          />
        )}
      </div>

      {/* small editorial placard pinned to the loop */}
      <div className="mt-3 flex items-center gap-3 font-mono text-[10px] uppercase tracking-[0.22em] text-ink-dim">
        <span className="block w-6 h-px bg-ink/30" />
        <span>fig. 01 · six rails, one junction, six destinations</span>
      </div>
    </div>
  )
}

function Hero() {
  const ref = useRef<HTMLElement>(null)
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start start', 'end start'] })
  const o = useTransform(scrollYProgress, [0.5, 1], [1, 0])
  const y = useTransform(scrollYProgress, [0, 1], [0, -80])

  return (
    <motion.section
      ref={ref}
      className="relative min-h-[100svh] flex flex-col px-8 pt-20 pb-12"
      style={{ opacity: o, y }}
    >
      <div className="flex-1 grid lg:grid-cols-[1.4fr_1fr] gap-10 items-center">
        <div>
          <motion.div
            className="font-mono text-[12px] uppercase tracking-[0.18em] text-ink-2 mb-8 flex items-center gap-3"
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
          >
            <span className="block w-9 h-px bg-ink" /> a link router for macOS · v0.10
          </motion.div>

          <h1 className="display text-[clamp(80px,16vw,220px)] leading-[0.84] tracking-[-0.005em]">
            <motion.span
              className="block"
              initial={{ opacity: 0, y: 40 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.9, ease: [0.16, 1, 0.3, 1] }}
            >
              Route
            </motion.span>
            <motion.span
              className="block text-tang"
              initial={{ opacity: 0, y: 40 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.9, delay: 0.1, ease: [0.16, 1, 0.3, 1] }}
            >
              every link
            </motion.span>
            <motion.span
              className="block"
              style={{ WebkitTextStroke: '2.5px var(--color-ink)', color: 'transparent' }}
              initial={{ opacity: 0, y: 40 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.9, delay: 0.2, ease: [0.16, 1, 0.3, 1] }}
            >
              you click.
            </motion.span>
          </h1>
        </div>

        <motion.div
          className="lg:justify-self-end w-full lg:max-w-[560px]"
          initial={{ opacity: 0, scale: 0.96 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 1.2, delay: 0.4, ease: [0.16, 1, 0.3, 1] }}
        >
          <HeroLoopAside />
        </motion.div>
      </div>

      <motion.div
        className="flex flex-wrap items-end justify-between gap-6 pt-8 border-t border-ink/15"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 0.6, delay: 0.7 }}
      >
        <p className="max-w-[36ch] text-[19px] leading-[1.4] text-ink-2">
          Sits in your menu bar. Hands every click to the right browser, profile, or private window. <b className="text-ink">Click the picker</b>.
        </p>
        <div className="flex items-center gap-3">
          <a
            href="https://github.com/TheTobiGit/junction/releases/latest"
            className="group inline-flex items-center gap-3 bg-ink text-paper px-6 py-4 font-display text-[20px] tracking-[0.04em] uppercase shadow-[6px_6px_0_0_var(--color-ink)] transition-all duration-300 ease-[var(--ease-out-expo)] hover:-translate-x-[3px] hover:-translate-y-[3px] hover:shadow-[9px_9px_0_0_var(--color-ink)] hover:bg-tang-deep active:translate-x-[2px] active:translate-y-[2px] active:shadow-[2px_2px_0_0_var(--color-ink)]"
          >
            Download
            <span className="text-[26px] leading-none transition-transform group-hover:translate-x-1">→</span>
          </a>
          <span className="font-mono text-[11px] uppercase tracking-[0.14em] text-ink-dim">macOS 13+ · 18 MB · MIT</span>
        </div>
      </motion.div>
    </motion.section>
  )
}

/* ---------------- act 2: interactive picker ---------------- */

function PickerAct() {
  const { open } = usePicker()
  const ref = useRef<HTMLElement>(null)
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start end', 'end start'] })
  const titleY = useTransform(scrollYProgress, [0, 0.4], [40, 0])
  const titleOpacity = useTransform(scrollYProgress, [0, 0.3], [0, 1])

  return (
    <section ref={ref} id="picker" className="px-8 py-40 max-w-[1280px] mx-auto">
      <div className="grid lg:grid-cols-[1fr_1.6fr] gap-16 items-start">
        <motion.div
          className="lg:sticky lg:top-32"
          style={{ opacity: titleOpacity, y: titleY }}
        >
          <div className="font-mono text-[11px] uppercase tracking-[0.18em] text-ink-2 mb-6">// 02 picker</div>
          <h2 className="display text-[clamp(48px,6vw,96px)] leading-[0.9] tracking-[-0.005em]">
            <span className="text-tang">Click</span> any link.<br />
            The picker is <span style={{ WebkitTextStroke: '2.5px var(--color-ink)', color: 'transparent' }}>real</span>.
          </h2>
          <p className="mt-6 max-w-[36ch] text-[17px] leading-[1.5] text-ink-2">
            One log, one keyboard. Hit a number. Hold <span className="kbd">⌥</span> for a private window.
          </p>
          <div className="mt-8 grid grid-cols-2 gap-x-6 gap-y-3">
            {keymap.map((k) => (
              <div key={k.keys} className="flex items-center gap-3 text-[13px] text-ink-2">
                <span className="kbd min-w-[36px]">{k.keys}</span>
                <span>{k.label}</span>
              </div>
            ))}
          </div>
        </motion.div>

        <div>
          <div className="flex items-baseline justify-between border-b border-ink pb-3 mb-2 font-mono text-[10px] uppercase tracking-[0.18em] text-ink-2">
            <span>// today · incoming links</span>
            <span>{hosts.length} routed</span>
          </div>
          <ul>
            {hosts.map((h, i) => (
              <LinkRow key={h.host} h={h} index={i} onPick={(priv) => open({ url: `https://${h.host}${h.path}`, host: h.host, priv })} />
            ))}
          </ul>
          <div className="mt-8 flex items-center gap-3 font-mono text-[11px] text-ink-dim">
            <span className="block flex-1 h-px bg-ink/15" />
            <span>tip · hold <span className="kbd">⌥</span> while clicking for a private window</span>
            <span className="block flex-1 h-px bg-ink/15" />
          </div>
        </div>
      </div>
    </section>
  )
}

function LinkRow({
  h,
  index,
  onPick,
}: {
  h: (typeof hosts)[number]
  index: number
  onPick: (priv: boolean) => void
}) {
  const ref = useRef<HTMLLIElement>(null)
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start 0.95', 'start 0.55'] })
  const x = useTransform(scrollYProgress, [0, 1], [-30, 0])
  const o = useTransform(scrollYProgress, [0, 1], [0, 1])
  return (
    <motion.li
      ref={ref}
      style={{ x, opacity: o }}
      className="relative border-b border-ink/15"
    >
      <button
        onClick={(e) => onPick(e.altKey || !!h.priv)}
        className="group grid w-full items-baseline gap-x-6 gap-y-1 py-6 text-left transition-colors duration-300 hover:bg-paper-2/30
                   grid-cols-[60px_1fr_auto_24px] sm:grid-cols-[64px_140px_1fr_auto_24px]"
      >
        <span className="font-mono text-[11px] uppercase tracking-[0.14em] text-ink-dim col-span-1">{h.at}</span>
        <span className="font-mono text-[12px] text-tang-deep hidden sm:inline">{h.host}</span>
        <span className="col-span-1 sm:col-span-1">
          <span className="font-mono text-[11px] text-tang-deep block sm:hidden mb-1">{h.host}</span>
          <span
            className="block font-medium leading-[1.05] tracking-[-0.015em] transition-all duration-500 ease-[var(--ease-out-expo)] group-hover:text-tang-deep"
            style={{ fontSize: `clamp(${20 - index * 0.5}px, ${2.2 - index * 0.05}vw, ${30 - index * 0.6}px)` }}
          >
            {h.title}
          </span>
          <span className="mt-1 block font-mono text-[10px] text-ink-dim truncate">{h.path}</span>
        </span>
        <span className="font-mono text-[10px] uppercase tracking-[0.12em] text-ink-dim hidden sm:inline">
          from {h.source}{h.priv ? ' · private' : ''}
        </span>
        <span className="justify-self-end self-center font-mono text-[18px] text-ink-dim transition-all duration-300 group-hover:text-tang group-hover:translate-x-1">
          {h.priv ? '⊘' : '↗'}
        </span>
      </button>
    </motion.li>
  )
}

/* ---------------- act 4: the rule ---------------- */

function RuleAct() {
  const ref = useRef<HTMLElement>(null)
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start end', 'end start'] })
  const cmd = `junction rules add github.com --in chrome:work`
  const len = useTransform(scrollYProgress, [0.18, 0.48], [0, cmd.length])
  const [text, setText] = useState('')
  useEffect(() => {
    const u = len.on('change', (v: number) => setText(cmd.slice(0, Math.round(v))))
    return () => u()
  }, [len, cmd])

  const rules = [
    { host: 'github.com', to: 'Chrome · Work', key: '1', priv: false },
    { host: 'figma.com', to: 'Arc', key: '2', priv: false },
    { host: '*.bank', to: 'Safari · Private', key: '⌥ + 4', priv: true },
    { host: 'localhost:*', to: 'Chrome · Canary', key: '5', priv: false },
    { host: 'mail.google.com', to: 'Chrome · Personal', key: '3', priv: false },
  ]

  return (
    <section ref={ref} id="rule" className="px-8 py-40 max-w-[1280px] mx-auto">
      <div className="grid lg:grid-cols-[1fr_1.6fr] gap-16 items-start">
        <div className="lg:sticky lg:top-32">
          <div className="font-mono text-[11px] uppercase tracking-[0.18em] text-ink-2 mb-6">// 03 the rule</div>
          <h2 className="display text-[clamp(48px,6vw,96px)] leading-[0.9] tracking-[-0.005em]">
            Teach it once.<br />
            <span className="text-tang">Retire</span> the picker.
          </h2>
          <p className="mt-6 max-w-[36ch] text-[17px] leading-[1.5] text-ink-2">
            One line in your terminal binds a host to a destination. That host never asks again.
          </p>

          <div className="mt-10 bg-ink text-paper rounded-[14px] p-5 font-mono text-[14px] sm:text-[15px] shadow-[0_30px_80px_-40px_oklch(0%_0_0/.5)] overflow-hidden">
            <div className="flex items-center gap-2 mb-4 text-ink-dim text-[10px] uppercase tracking-[0.16em]">
              <span className="block w-2.5 h-2.5 rounded-full bg-paper/20" />
              <span className="block w-2.5 h-2.5 rounded-full bg-paper/20" />
              <span className="block w-2.5 h-2.5 rounded-full bg-paper/20" />
              <span className="ml-2 text-paper/60">~/junction</span>
            </div>
            <div className="whitespace-pre-wrap break-all">
              <span className="text-tang-soft">$</span>{' '}
              <span>{text}</span>
              <motion.span
                className="inline-block w-[7px] h-[16px] ml-0.5 -mb-0.5 align-middle bg-tang"
                animate={{ opacity: [1, 1, 0, 0] }}
                transition={{ duration: 1, repeat: Infinity, times: [0, 0.5, 0.5, 1] }}
              />
            </div>
          </div>
        </div>

        <div>
          <div className="flex items-baseline justify-between border-b border-ink pb-3 mb-2 font-mono text-[10px] uppercase tracking-[0.18em] text-ink-2">
            <span>// rules in effect · ~/.junction/rules</span>
            <span>{rules.length} bound</span>
          </div>
          <ul>
            {rules.map((r, i) => (
              <RuleRow key={r.host} index={i} rule={r} />
            ))}
          </ul>
          <div className="mt-6 font-mono text-[11px] text-ink-dim">
            <span className="text-tang-deep">// </span>
            anything not bound still goes through the picker. nothing is hidden.
          </div>
        </div>
      </div>
    </section>
  )
}

function RuleRow({
  index,
  rule,
}: {
  index: number
  rule: { host: string; to: string; key: string; priv: boolean }
}) {
  const ref = useRef<HTMLLIElement>(null)
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start 0.95', 'start 0.55'] })
  const x = useTransform(scrollYProgress, [0, 1], [-30, 0])
  const o = useTransform(scrollYProgress, [0, 1], [0, 1])
  const fontSize = `clamp(${22 - index * 0.6}px, ${2.4 - index * 0.06}vw, ${30 - index * 0.8}px)`
  return (
    <motion.li
      ref={ref}
      style={{ x, opacity: o }}
      className="border-b border-ink/15 grid items-baseline gap-x-6 py-5 grid-cols-[1fr_auto_1fr_auto] sm:grid-cols-[1.2fr_24px_1fr_auto]"
    >
      <span
        className="font-medium tracking-[-0.015em] leading-none"
        style={{ fontSize, color: rule.priv ? 'var(--color-priv)' : 'var(--color-ink)' }}
      >
        {rule.host}
      </span>
      <span className="font-mono text-[14px] text-ink-dim justify-self-center">→</span>
      <span className="font-mono text-[14px] text-ink-2">
        {rule.to}
      </span>
      <span className="font-mono text-[10px] uppercase tracking-[0.14em] text-ink-dim">
        bound · {rule.key}
      </span>
    </motion.li>
  )
}

/* ---------------- act 5: anti-promise ---------------- */

function AntiPromise() {
  const ref = useRef<HTMLElement>(null)
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start end', 'end start'] })
  const lineO = useTransform(scrollYProgress, [0.1, 0.4], [0, 1])

  const negations = [
    'a browser',
    'a sync layer',
    'an account',
    'a network call',
    'a roadmap',
  ]
  const promises = [
    'a hallway',
    'a keyboard',
    '18 megabytes',
    '< 80 ms',
    'open source',
  ]

  return (
    <section ref={ref} className="px-8 py-32 max-w-[1100px] mx-auto">
      <motion.div style={{ opacity: lineO }} className="grid md:grid-cols-2 gap-12 md:gap-16">
        <div>
          <div className="font-mono text-[10px] uppercase tracking-[0.2em] text-ink-dim mb-6">// what it is not</div>
          <ul className="font-display text-[clamp(40px,5.5vw,80px)] leading-[0.92] tracking-[-0.005em] space-y-1">
            {negations.map((n) => (
              <li key={n} className="flex items-baseline gap-3">
                <span className="text-ink-dim text-[0.5em] leading-none -translate-y-1">×</span>
                <span style={{ WebkitTextStroke: '1.8px var(--color-ink)', color: 'transparent' }}>{n}</span>
              </li>
            ))}
          </ul>
        </div>
        <div>
          <div className="font-mono text-[10px] uppercase tracking-[0.2em] text-ink-dim mb-6">// what it is</div>
          <ul className="font-display text-[clamp(40px,5.5vw,80px)] leading-[0.92] tracking-[-0.005em] space-y-1">
            {promises.map((p, i) => (
              <li key={p} className="flex items-baseline gap-3">
                <span className={`text-[0.5em] leading-none -translate-y-1 ${i === 0 ? 'text-tang' : 'text-ink-dim'}`}>·</span>
                <span className={i === 0 ? 'text-tang' : 'text-ink'}>{p}</span>
              </li>
            ))}
          </ul>
        </div>
      </motion.div>
    </section>
  )
}

/* ---------------- act 6: cta ---------------- */

function Cta() {
  const ref = useRef<HTMLElement>(null)
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start end', 'end end'] })
  const wipe = useTransform(scrollYProgress, [0.2, 0.8], ['0%', '100%'])
  const labelO = useTransform(scrollYProgress, [0.4, 0.7], [0, 1])

  return (
    <section ref={ref} className="relative px-8 py-32">
      <div className="max-w-[1280px] mx-auto">
        {/* the closing line, set as a single committed sentence with the wipe revealing the period */}
        <h2 className="display text-[clamp(64px,12vw,180px)] leading-[0.9] tracking-[-0.005em] text-center">
          Click any link.
          <br />
          Land where you <span className="text-tang">meant</span> to.
        </h2>

        {/* the bar - a single ink rail that fills tangerine as you scroll into the CTA */}
        <div className="relative mt-20 mx-auto max-w-[640px]">
          <div className="relative h-[2px] bg-ink/15 overflow-hidden">
            <motion.div
              className="absolute inset-y-0 left-0 bg-tang"
              style={{ width: wipe }}
            />
          </div>
          <motion.div
            className="absolute -top-2 w-[14px] h-[14px] rounded-full bg-tang"
            style={{ left: wipe, transform: 'translateX(-50%)' }}
          />
          <motion.div
            className="mt-6 flex items-baseline justify-between font-mono text-[11px] uppercase tracking-[0.18em] text-ink-dim"
            style={{ opacity: labelO }}
          >
            <span>now</span>
            <span className="text-tang-deep">→ junction · v0.10 · macOS 13+</span>
          </motion.div>
        </div>

        {/* CTA pair - varied weight, no shadow box stamp echoing the hero */}
        <div className="mt-12 flex flex-col items-center gap-5">
          <a
            href="https://github.com/TheTobiGit/junction/releases/latest"
            className="group inline-flex items-baseline gap-4 px-1 pb-3 border-b-[3px] border-ink hover:border-tang transition-colors duration-300"
          >
            <span className="display text-[clamp(40px,5.5vw,80px)] leading-none tracking-[-0.005em] group-hover:text-tang-deep transition-colors duration-300">
              Download
            </span>
            <motion.span
              className="display text-[clamp(40px,5.5vw,80px)] leading-none text-tang"
              animate={{ x: [0, 8, 0] }}
              transition={{ duration: 1.4, repeat: Infinity, ease: 'easeInOut' }}
            >
              ↘
            </motion.span>
          </a>
          <span className="font-mono text-[11px] uppercase tracking-[0.18em] text-ink-dim">
            18 MB · MIT · no telemetry · no account
          </span>
        </div>
      </div>
    </section>
  )
}

function Footer() {
  return (
    <footer className="px-8 pt-16 pb-10 border-t border-ink">
      <div className="max-w-[1280px] mx-auto grid gap-10 md:grid-cols-[1.5fr_1fr_1fr] items-start">
        <div>
          <div className="flex items-center gap-2.5 mb-4">
            <LogoMark size={20} />
            <span className="font-display text-[18px] tracking-[0.02em]">Junction</span>
          </div>
          <p className="text-[15px] leading-[1.5] text-ink-2 max-w-[34ch]">
            A small, fast, keyboard-first link router for macOS. Open source. No account, no telemetry, no network call.
          </p>
        </div>

        <div>
          <div className="font-mono text-[10px] uppercase tracking-[0.18em] text-ink-dim mb-3">build from source</div>
          <pre className="font-mono text-[12px] bg-ink text-paper rounded-md p-3 overflow-x-auto leading-[1.55]"><span className="text-tang-soft">$</span> git clone github.com/TheTobiGit/junction
<span className="text-tang-soft">$</span> ./build-app.sh release</pre>
          <a
            href="https://github.com/TheTobiGit/junction/releases/latest"
            className="mt-3 inline-flex items-center gap-2 font-mono text-[11px] uppercase tracking-[0.12em] hover:text-tang-deep transition-colors"
          >
            <span>or download .dmg</span> <span>↗</span>
          </a>
        </div>

        <div>
          <div className="font-mono text-[10px] uppercase tracking-[0.18em] text-ink-dim mb-3">elsewhere</div>
          <ul className="space-y-2 text-[14px]">
            <li>
              <a href="https://github.com/TheTobiGit/junction" className="border-b border-ink/30 hover:border-ink transition-colors">github · TheTobiGit/junction</a>
            </li>
            <li>
              <a href="https://github.com/TheTobiGit/junction/issues" className="border-b border-ink/30 hover:border-ink transition-colors">report an issue</a>
            </li>
            <li>
              <a href="https://github.com/TheTobiGit/junction/blob/main/SECURITY.md" className="border-b border-ink/30 hover:border-ink transition-colors">security disclosure</a>
            </li>
          </ul>
        </div>
      </div>

      <div className="max-w-[1280px] mx-auto mt-12 pt-6 border-t border-ink/15 flex flex-wrap justify-between gap-3 font-mono text-[11px] uppercase tracking-[0.1em] text-ink-dim">
        <span>MIT · 2026 · made for the link you are about to click</span>
        <span>built with vite + remotion · oklch ink &amp; tangerine</span>
      </div>
    </footer>
  )
}

/* ---------------- root ---------------- */

export default function App() {
  return (
    <PickerProvider>
      <Nav />
      <main>
        <Hero />
        <PickerAct />
        <RuleAct />
        <AntiPromise />
        <Cta />
        <Footer />
      </main>
    </PickerProvider>
  )
}
