import { useEffect, useRef, useState } from 'react'
import { Dialog } from '@base-ui/react/dialog'
import { motion, useScroll, useTransform, useReducedMotion } from 'motion/react'
import { keymap } from './data'

/* ---------------- cheat sheet (press ? — same as in the app) ---------------- */

function CheatSheet() {
  const [open, setOpen] = useState(false)
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== '?' || e.metaKey || e.ctrlKey) return
      const t = e.target as HTMLElement | null
      if (t && (t.tagName === 'INPUT' || t.tagName === 'TEXTAREA' || t.isContentEditable)) return
      setOpen((o) => !o)
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [])

  return (
    <Dialog.Root open={open} onOpenChange={setOpen}>
      <Dialog.Portal>
        <Dialog.Backdrop className="fixed inset-0 z-[80] bg-[oklch(8%_0_0/.45)] backdrop-blur-md data-[starting-style]:opacity-0 transition-opacity duration-200" />
        <Dialog.Popup
          className={
            'fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 z-[81] w-[min(440px,92vw)] outline-none ' +
            'rounded-[14px] border border-rule bg-paper shadow-[0_30px_80px_-10px_oklch(0%_0_0_/_.35),inset_0_1px_0_oklch(100%_0_0_/_.04)] ' +
            'data-[starting-style]:opacity-0 data-[starting-style]:scale-[.98] data-[starting-style]:translate-y-[-46%] transition-[opacity,transform] duration-300 ease-[var(--ease-out-expo)]'
          }
        >
          <div className="p-5">
            <div className="flex items-baseline justify-between pb-3 border-b border-rule">
              <span className="font-display text-[18px] tracking-[0.04em] uppercase">Cheat sheet</span>
              <span className="font-mono text-[10px] uppercase tracking-[0.14em] text-ink-dim">same keys as the app</span>
            </div>
            <div className="mt-4 flex flex-col gap-2.5">
              {keymap.map((k) => (
                <div key={k.keys} className="flex items-center justify-between text-[14px]">
                  <span className="text-ink-2">{k.label}</span>
                  <span className="kbd">{k.keys}</span>
                </div>
              ))}
            </div>
            <div className="mt-4 pt-3 border-t border-rule font-mono text-[10px] uppercase tracking-[0.14em] text-ink-dim">
              <span className="kbd">esc</span> <span className="ml-1">to close</span>
            </div>
          </div>
        </Dialog.Popup>
      </Dialog.Portal>
    </Dialog.Root>
  )
}

/* ---------------- shared bits ---------------- */

function LogoMark({ size = 28 }: { size?: number }) {
  return (
    <img
      src="/logo.png"
      alt="Junction"
      style={{ width: size, height: size }}
      className="rounded-[22%]"
    />
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
            <span className="block w-9 h-px bg-ink" /> a link router for macOS · v0.13
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
          Sits in your menu bar. Hands every click to the right browser, profile, or private window. <b className="text-ink">One keystroke ends it</b>.
        </p>
        <div className="flex items-center gap-3">
          <a
            href="https://github.com/TheTobiGit/junction/releases/latest"
            className="group inline-flex items-center gap-3 bg-ink text-paper px-6 py-4 font-display text-[20px] tracking-[0.04em] uppercase shadow-[6px_6px_0_0_var(--color-ink)] transition-all duration-300 ease-[var(--ease-out-expo)] hover:-translate-x-[3px] hover:-translate-y-[3px] hover:shadow-[9px_9px_0_0_var(--color-ink)] hover:bg-tang-deep active:translate-x-[2px] active:translate-y-[2px] active:shadow-[2px_2px_0_0_var(--color-ink)]"
          >
            Download
            <span className="text-[26px] leading-none transition-transform group-hover:translate-x-1">→</span>
          </a>
          <span className="font-mono text-[11px] uppercase tracking-[0.14em] text-ink-dim">macOS 13+</span>
        </div>
      </motion.div>
    </motion.section>
  )
}

/* ---------------- act 3: the keys ---------------- */

function KeyRow({ k, index }: { k: (typeof keymap)[number]; index: number }) {
  const ref = useRef<HTMLLIElement>(null)
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start 0.95', 'start 0.6'] })
  const x = useTransform(scrollYProgress, [0, 1], [-30, 0])
  const o = useTransform(scrollYProgress, [0, 1], [0, 1])
  return (
    <motion.li
      ref={ref}
      style={{ x, opacity: o }}
      className="group grid items-baseline gap-x-6 gap-y-1 py-5 border-b border-ink/15 grid-cols-[72px_1fr] sm:grid-cols-[88px_220px_1fr]"
    >
      <span className="kbd justify-self-start !text-[15px] !px-3 !py-1.5 transition-colors duration-300 group-hover:border-tang-deep group-hover:text-tang-deep">
        {k.keys}
      </span>
      <span
        className="font-medium leading-[1.05] tracking-[-0.015em] transition-colors duration-300 group-hover:text-tang-deep"
        style={{ fontSize: `clamp(${22 - index * 0.6}px, ${2.3 - index * 0.06}vw, ${28 - index * 0.7}px)` }}
      >
        {k.label}
      </span>
      <span className="font-mono text-[11px] text-ink-dim col-start-1 col-span-2 sm:col-start-3 sm:col-span-1 sm:justify-self-end sm:text-right">
        {k.detail}
      </span>
    </motion.li>
  )
}

function PickerAct() {
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
          <div className="font-mono text-[11px] uppercase tracking-[0.18em] text-ink-2 mb-6">// 03 the keys</div>
          <h2 className="display text-[clamp(48px,6vw,96px)] leading-[0.9] tracking-[-0.005em]">
            <span className="text-tang">Click</span> any link.<br />
            Keys do the <span style={{ WebkitTextStroke: '2.5px var(--color-ink)', color: 'transparent' }}>rest</span>.
          </h2>
          <p className="mt-6 max-w-[36ch] text-[17px] leading-[1.5] text-ink-2">
            The picker opens already listening. Hit a number and it&apos;s gone. No mouse, no tab roulette.
          </p>
          <div className="mt-6 font-mono text-[11px] text-ink-dim">
            <span className="text-tang-deep">// </span>
            press <span className="kbd">?</span> right now. It works on this page too.
          </div>
        </motion.div>

        <div>
          <div className="flex items-baseline justify-between border-b border-ink pb-3 mb-2 font-mono text-[10px] uppercase tracking-[0.18em] text-ink-2">
            <span>// every key · picker</span>
            <span>{keymap.length} bound</span>
          </div>
          <ul>
            {keymap.map((k, i) => (
              <KeyRow key={k.keys} k={k} index={i} />
            ))}
          </ul>
        </div>
      </div>
    </section>
  )
}

/* ---------------- act 2: the real thing (screenshots) ---------------- */

/* w = width relative to the desktop, so each picker keeps its real on-screen scale */
const shots = [
  { id: 'tile', label: 'Tile', src: '/app/picker-tile.webp', w: '74%' },
  { id: 'dial', label: 'Dial', src: '/app/picker-dial.webp', w: '40%' },
  { id: 'list', label: 'List', src: '/app/picker-list.webp', w: '42%' },
]

/* a minimal macOS desktop: wallpaper, frosted menu bar, Junction in the status area */
function DesktopFrame({ children }: { children: React.ReactNode }) {
  return (
    <div className="relative aspect-[16/10] overflow-hidden rounded-[18px] shadow-[0_40px_100px_-50px_oklch(0%_0_0/.55)]">
      <div
        className="absolute inset-0"
        style={{
          background:
            'radial-gradient(120% 90% at 72% -10%, oklch(46% 0.06 268) 0%, oklch(33% 0.05 274) 48%, oklch(23% 0.04 280) 100%)',
        }}
      />
      <div
        className="absolute inset-0"
        style={{
          background:
            'radial-gradient(55% 45% at 18% 105%, oklch(58% 0.14 48 / .22) 0%, transparent 70%)',
        }}
      />
      <div className="absolute top-0 inset-x-0 z-10 h-7 flex items-center justify-between px-4 bg-[oklch(22%_0.02_270/.55)] backdrop-blur-sm font-sans text-[11px] text-[oklch(94%_0.005_270/.85)]">
        <div className="flex items-center gap-4">
          <span className="font-semibold">Messages</span>
          <span className="opacity-55 hidden sm:inline">File</span>
          <span className="opacity-55 hidden sm:inline">Edit</span>
          <span className="opacity-55 hidden sm:inline">View</span>
        </div>
        <div className="flex items-center gap-3">
          <img src="/logo.png" alt="Junction in the menu bar" className="w-[15px] h-[15px] rounded-[3px]" />
          <span className="opacity-75">Fri 9:41 AM</span>
        </div>
      </div>
      <div className="absolute inset-0 pt-7">{children}</div>
    </div>
  )
}

function ShowcaseAct() {
  const [active, setActive] = useState(0)
  const ref = useRef<HTMLElement>(null)
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start end', 'end start'] })
  const titleY = useTransform(scrollYProgress, [0, 0.3], [40, 0])
  const titleOpacity = useTransform(scrollYProgress, [0, 0.22], [0, 1])

  return (
    <section ref={ref} id="showcase" className="px-8 py-40 max-w-[1280px] mx-auto">
      <motion.div
        style={{ opacity: titleOpacity, y: titleY }}
        className="flex flex-wrap items-end justify-between gap-8"
      >
        <div>
          <div className="font-mono text-[11px] uppercase tracking-[0.18em] text-ink-2 mb-6">// 02 in the flesh</div>
          <h2 className="display text-[clamp(48px,6vw,96px)] leading-[0.9] tracking-[-0.005em]">
            Three pickers.<br />
            One <span className="text-tang">reflex</span>.
          </h2>
        </div>
        <div className="max-w-[38ch]">
          <p className="text-[17px] leading-[1.5] text-ink-2">
            Three views, one picker. List, tile, or dial. Same contacts, same shortcuts. Choose your default in settings.
          </p>
          <div className="mt-5 flex gap-2">
            {shots.map((s, i) => (
              <button
                key={s.id}
                onClick={() => setActive(i)}
                className={
                  'px-4 py-2 font-mono text-[11px] uppercase tracking-[0.14em] border transition-colors duration-200 ' +
                  (i === active
                    ? 'bg-ink text-paper border-ink'
                    : 'border-ink/30 text-ink-2 hover:border-ink')
                }
              >
                {s.label}
              </button>
            ))}
          </div>
        </div>
      </motion.div>

      <motion.div
        className="mt-12"
        initial={{ opacity: 0, y: 40, scale: 0.98 }}
        whileInView={{ opacity: 1, y: 0, scale: 1 }}
        viewport={{ once: true, margin: '-100px' }}
        transition={{ duration: 0.9, ease: [0.16, 1, 0.3, 1] }}
      >
        <DesktopFrame>
          <div className="relative h-full">
            {shots.map((s, i) => (
              <img
                key={s.id}
                src={s.src}
                alt={`Junction ${s.label.toLowerCase()} picker, screenshot of the running app`}
                loading="lazy"
                style={{ width: s.w }}
                className={
                  'absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 max-h-[84%] object-contain ' +
                  'transition-opacity duration-500 ease-[var(--ease-out-expo)] ' +
                  (i === active ? 'opacity-100' : 'opacity-0 pointer-events-none')
                }
              />
            ))}
          </div>
        </DesktopFrame>
      </motion.div>

      {/* the preview: full-bleed second figure */}
      <div className="mt-28 grid lg:grid-cols-[1fr_1.6fr] gap-12 items-center">
        <motion.div
          initial={{ opacity: 0, y: 40 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: '-100px' }}
          transition={{ duration: 0.8, ease: [0.16, 1, 0.3, 1] }}
        >
          <h3 className="display text-[clamp(36px,4.5vw,64px)] leading-[0.9] tracking-[-0.005em]">
            Press <span className="kbd !text-[0.45em] !align-middle">␣</span>.<br />
            See the page<br />
            <span style={{ WebkitTextStroke: '2px var(--color-ink)', color: 'transparent' }}>before</span> you commit.
          </h3>
          <p className="mt-6 max-w-[34ch] text-[16px] leading-[1.5] text-ink-2">
            The preview renders the page inside the picker while slots stay live underneath, so you can read first and route after. Pin it to keep it open.
          </p>
        </motion.div>
        <motion.div
          initial={{ opacity: 0, y: 40, scale: 0.98 }}
          whileInView={{ opacity: 1, y: 0, scale: 1 }}
          viewport={{ once: true, margin: '-100px' }}
          transition={{ duration: 0.9, delay: 0.12, ease: [0.16, 1, 0.3, 1] }}
        >
          <DesktopFrame>
            <div className="h-full grid place-items-center">
              <img
                src="/app/picker-preview.webp"
                alt="Junction URL preview, the page rendered above the picker slots"
                loading="lazy"
                className="w-[78%] max-h-[88%] object-contain rounded-[8px] shadow-[0_20px_60px_-20px_oklch(0%_0_0/.6)]"
              />
            </div>
          </DesktopFrame>
        </motion.div>
      </div>
    </section>
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
          <div className="font-mono text-[11px] uppercase tracking-[0.18em] text-ink-2 mb-6">// 04 the rule</div>
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
          <div className="mt-4 font-mono text-[11px] text-ink-dim">
            <span className="text-tang-deep">// </span>
            allergic to terminals? hit <span className="kbd">⌘↵</span> remember in the picker instead.
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

/* ---------------- act 6: setup ---------------- */

const setupSteps = [
  {
    n: '01',
    title: 'Download',
    body: 'One notarized .dmg, 18 MB. Drag it to Applications like it’s 2008.',
    aside: 'no installer · no launch agents',
  },
  {
    n: '02',
    title: 'Make it the default',
    body: 'Junction asks on first launch. From then on, every link reports to the junction before it goes anywhere.',
    aside: 'switch back anytime · system settings',
  },
  {
    n: '03',
    title: 'Click a link',
    body: 'Slack, Mail, Terminal, a PDF. The picker appears. Or a rule routes it before you see anything at all.',
    aside: 'that’s it · there is no step four',
  },
]

const extras = [
  'dial or list picker',
  'favorite profile, starred',
  '␣ inline url preview',
  'searchable activity log',
  'routes local html files',
  'in-app updates',
]

function SetupAct() {
  const ref = useRef<HTMLElement>(null)
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start end', 'end start'] })
  const titleY = useTransform(scrollYProgress, [0, 0.35], [40, 0])
  const titleOpacity = useTransform(scrollYProgress, [0, 0.25], [0, 1])

  return (
    <section ref={ref} id="setup" className="px-8 py-40 max-w-[1280px] mx-auto">
      <motion.div style={{ opacity: titleOpacity, y: titleY }}>
        <div className="font-mono text-[11px] uppercase tracking-[0.18em] text-ink-2 mb-6">// 05 setup</div>
        <h2 className="display text-[clamp(48px,6vw,96px)] leading-[0.9] tracking-[-0.005em]">
          Sixty seconds,<br />
          <span style={{ WebkitTextStroke: '2.5px var(--color-ink)', color: 'transparent' }}>start</span> to <span className="text-tang">routed</span>.
        </h2>
      </motion.div>

      <div className="mt-16 grid md:grid-cols-3 gap-px bg-ink/15 border border-ink/15">
        {setupSteps.map((s, i) => (
          <motion.div
            key={s.n}
            className="bg-paper p-8 flex flex-col gap-4 min-h-[260px]"
            initial={{ opacity: 0, y: 24 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: '-80px' }}
            transition={{ duration: 0.7, delay: i * 0.12, ease: [0.16, 1, 0.3, 1] }}
          >
            <span className="display text-[64px] leading-none text-tang">{s.n}</span>
            <h3 className="font-display text-[26px] tracking-[0.02em] uppercase leading-none">{s.title}</h3>
            <p className="text-[15px] leading-[1.5] text-ink-2 flex-1">{s.body}</p>
            <span className="font-mono text-[10px] uppercase tracking-[0.16em] text-ink-dim">{s.aside}</span>
          </motion.div>
        ))}
      </div>

      <div className="mt-10 flex flex-wrap items-baseline gap-x-2 gap-y-3 font-mono text-[11px] uppercase tracking-[0.14em] text-ink-2">
        <span className="text-ink-dim mr-2">also in the box</span>
        {extras.map((x, i) => (
          <span key={x}>
            {i > 0 && <span className="text-ink-dim mr-2">·</span>}
            <span className="border-b border-ink/25">{x}</span>
          </span>
        ))}
      </div>
    </section>
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
    'local',
    'keyboard-first',
    'rule-driven',
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

/* ---------------- act 7: cta ---------------- */

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
            <span className="text-tang-deep">→ junction · v0.13 · macOS 13+</span>
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
            18 MB · no telemetry · no account
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
            <LogoMark size={24} />
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

      <div className="max-w-[1280px] mx-auto mt-12 pt-6 flex flex-wrap justify-between gap-3 font-mono text-[11px] uppercase tracking-[0.1em] text-ink-dim">
        <span>2026 · made for the link you are about to click</span>
      </div>
    </footer>
  )
}

/* ---------------- root ---------------- */

export default function App() {
  return (
    <>
      <Nav />
      <main>
        <Hero />
        <ShowcaseAct />
        <PickerAct />
        <RuleAct />
        <AntiPromise />
        <SetupAct />
        <Cta />
        <Footer />
      </main>
      <CheatSheet />
    </>
  )
}
