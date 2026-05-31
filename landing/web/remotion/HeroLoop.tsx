import { AbsoluteFill, useCurrentFrame, interpolate, Easing, staticFile } from 'remotion'

const PAPER = 'oklch(96.5% 0.012 80)'
const INK = 'oklch(16% 0.012 260)'
const RULE = 'oklch(86% 0.01 80)'
const TANG = 'oklch(68% 0.20 48)'
const PRIV = 'oklch(56% 0.18 305)'

const W = 1200
const H = 1200
const JX = 600
const JY = 600
const JR = 90
const TOP_Y = 180
const BOT_Y = 1020
const ARM_TOP = 380
const ARM_BOT = 800

type Host = { x: number; y: number; label: string; icon: string }
type Dest = { x: number; y: number; name: string; sub: string; icon: string; priv?: boolean }

const hosts: Host[] = [
  { x: 150, y: TOP_Y, label: 'github.com', icon: 'github.svg' },
  { x: 330, y: TOP_Y, label: 'figma.com', icon: 'figma.svg' },
  { x: 510, y: TOP_Y, label: 'mail.google', icon: 'gmail.svg' },
  { x: 690, y: TOP_Y, label: 'notion.so', icon: 'notion.svg' },
  { x: 870, y: TOP_Y, label: 'linear.app', icon: 'linear.svg' },
  { x: 1050, y: TOP_Y, label: 'slack.com', icon: 'slack.svg' },
]

const dests: Dest[] = [
  { x: 150, y: BOT_Y, name: 'Chrome', sub: 'work', icon: 'chrome.svg' },
  { x: 330, y: BOT_Y, name: 'Arc', sub: 'default', icon: 'arc.svg' },
  { x: 510, y: BOT_Y, name: 'Chrome', sub: 'personal', icon: 'chrome.svg' },
  { x: 690, y: BOT_Y, name: 'Safari', sub: 'private', icon: 'safari.svg', priv: true },
  { x: 870, y: BOT_Y, name: 'Firefox', sub: 'dev', icon: 'firefox.svg' },
  { x: 1050, y: BOT_Y, name: 'Brave', sub: 'default', icon: 'brave.svg' },
]

const inPath = (h: Host) => `M ${h.x} ${h.y + 38} L ${h.x} ${ARM_TOP} L ${JX} ${ARM_TOP} L ${JX} ${JY}`
const outPath = (d: Dest) => `M ${JX} ${JY} L ${JX} ${ARM_BOT} L ${d.x} ${ARM_BOT} L ${d.x} ${d.y - 56}`

function pointsAlong(d: string, n: number) {
  const cmds = d.match(/[ML]\s*[-\d.]+\s+[-\d.]+/g) || []
  const pts = cmds.map((c) => {
    const m = c.match(/[-\d.]+/g)!
    return { x: parseFloat(m[0]), y: parseFloat(m[1]) }
  })
  const segLens: number[] = []
  let total = 0
  for (let i = 1; i < pts.length; i++) {
    const dx = pts[i].x - pts[i - 1].x
    const dy = pts[i].y - pts[i - 1].y
    const l = Math.hypot(dx, dy)
    segLens.push(l)
    total += l
  }
  const out: { x: number; y: number }[] = []
  for (let i = 0; i < n; i++) {
    const target = (i / (n - 1)) * total
    let acc = 0
    for (let s = 0; s < segLens.length; s++) {
      const segEnd = acc + segLens[s]
      if (segEnd >= target || s === segLens.length - 1) {
        const local = Math.max(0, Math.min(1, (target - acc) / segLens[s]))
        out.push({
          x: pts[s].x + (pts[s + 1].x - pts[s].x) * local,
          y: pts[s].y + (pts[s + 1].y - pts[s].y) * local,
        })
        break
      }
      acc = segEnd
    }
  }
  return out
}

const inboundPts = hosts.map((h) => pointsAlong(inPath(h), 240))
const outboundPts = dests.map((d) => pointsAlong(outPath(d), 240))

const FPS = 60
const ROUTE = 3 * FPS
const STAGGER = 1 * FPS
const LOOP = hosts.length * STAGGER

const wrap = (n: number, m: number) => ((n % m) + m) % m
const easeInOut = Easing.bezier(0.5, 0, 0.5, 1)

const ICON = (name: string) => staticFile(`brands/${name}`)

export const HeroLoop: React.FC = () => {
  const frame = useCurrentFrame()

  return (
    <AbsoluteFill style={{ backgroundColor: PAPER }}>
      <svg width={W} height={H} viewBox={`0 0 ${W} ${H}`}>
        <defs>
          <pattern id="g" width="40" height="40" patternUnits="userSpaceOnUse">
            <path d="M 40 0 L 0 0 0 40" fill="none" stroke={RULE} strokeWidth="0.6" opacity={0.4} />
          </pattern>
        </defs>
        <rect width={W} height={H} fill="url(#g)" />

        {/* persistent rails */}
        {hosts.map((h, i) => (
          <path
            key={`in${i}`}
            d={inPath(h)}
            stroke={INK}
            strokeWidth={2}
            fill="none"
            strokeLinecap="round"
            strokeLinejoin="round"
            opacity={0.85}
          />
        ))}
        {dests.map((d, i) => (
          <path
            key={`out${i}`}
            d={outPath(d)}
            stroke={INK}
            strokeWidth={2}
            fill="none"
            strokeLinecap="round"
            strokeLinejoin="round"
            opacity={0.85}
          />
        ))}

        {/* host stations: brand icon + monospaced url */}
        {hosts.map((h, i) => (
          <g key={`hs${i}`}>
            <rect
              x={h.x - 36}
              y={h.y - 36}
              width={72}
              height={72}
              rx={14}
              fill={PAPER}
              stroke={INK}
              strokeWidth={2}
            />
            <foreignObject x={h.x - 26} y={h.y - 26} width={52} height={52}>
              <img
                src={ICON(h.icon)}
                style={{ width: '100%', height: '100%', objectFit: 'contain', display: 'block' }}
                alt=""
              />
            </foreignObject>
            <text
              x={h.x}
              y={h.y + 60}
              textAnchor="middle"
              fontFamily="JetBrains Mono, monospace"
              fontSize={14}
              fill={INK}
              opacity={0.75}
            >
              {h.label}
            </text>
          </g>
        ))}

        {/* junction node */}
        <g>
          <circle cx={JX} cy={JY} r={JR} fill={PAPER} stroke={INK} strokeWidth={4} />
          <circle cx={JX} cy={JY} r={JR - 12} fill="none" stroke={INK} strokeWidth={1} opacity={0.25} />
          <circle cx={JX} cy={JY - 8} r={6} fill={INK} />
          <text
            x={JX}
            y={JY + 22}
            textAnchor="middle"
            fontFamily="Inter, sans-serif"
            fontWeight={700}
            fontSize={26}
            fill={INK}
            letterSpacing="-0.5"
          >
            JUNCTION
          </text>
          <text
            x={JX}
            y={JY + 46}
            textAnchor="middle"
            fontFamily="JetBrains Mono, monospace"
            fontSize={11}
            fill={INK}
            opacity={0.55}
            letterSpacing="2.5"
          >
            PRESS 1–9
          </text>
        </g>

        {/* destination boxes — flash when their route arrives */}
        {dests.map((d, i) => {
          const baseStart = i * STAGGER
          const elapsed = wrap(frame - baseStart, LOOP)
          const t = elapsed / ROUTE
          let flash = 0
          if (t >= 0.92 && t <= 1.12) {
            flash = interpolate(Math.abs(t - 1.0), [0, 0.12], [1, 0], { extrapolateRight: 'clamp' })
          }
          const accent = d.priv ? PRIV : TANG
          const fill = flash > 0.5 ? accent : PAPER
          const textColor = flash > 0.5 ? PAPER : INK
          const stroke = flash > 0.3 ? accent : INK
          return (
            <g key={`d${i}`}>
              <rect
                x={d.x - 70}
                y={d.y - 56}
                width={140}
                height={108}
                rx={6}
                fill={fill}
                stroke={stroke}
                strokeWidth={2}
              />
              <foreignObject x={d.x - 22} y={d.y - 46} width={44} height={44}>
                <img
                  src={ICON(d.icon)}
                  style={{ width: '100%', height: '100%', objectFit: 'contain', display: 'block', opacity: flash > 0.5 ? 0.92 : 1 }}
                  alt=""
                />
              </foreignObject>
              <text
                x={d.x}
                y={d.y + 14}
                textAnchor="middle"
                fontFamily="Inter, sans-serif"
                fontWeight={700}
                fontSize={16}
                fill={textColor}
                letterSpacing="-0.2"
              >
                {d.name}
              </text>
              <text
                x={d.x}
                y={d.y + 36}
                textAnchor="middle"
                fontFamily="JetBrains Mono, monospace"
                fontSize={11}
                fill={textColor}
                opacity={0.7}
                letterSpacing="0.5"
              >
                {d.sub}
              </text>
            </g>
          )
        })}

        {/* dispatch dots: one per route, staggered */}
        {hosts.map((_h, i) => {
          const baseStart = i * STAGGER
          const elapsed = wrap(frame - baseStart, LOOP)
          if (elapsed >= ROUTE) return null
          const t = elapsed / ROUTE
          const dest = dests[i]
          const isPriv = dest.priv
          const dotColor = isPriv ? PRIV : TANG

          let pos: { x: number; y: number }
          let phase: 'in' | 'hold' | 'out'
          let trailPath: { x: number; y: number }[] | null = null
          let trailHead = 0

          if (t < 0.42) {
            phase = 'in'
            const lt = t / 0.42
            const e = easeInOut(lt)
            const pts = inboundPts[i]
            const idx = Math.min(pts.length - 1, Math.round(e * (pts.length - 1)))
            pos = pts[idx]
            trailPath = pts
            trailHead = idx
          } else if (t < 0.58) {
            phase = 'hold'
            pos = { x: JX, y: JY }
          } else {
            phase = 'out'
            const lt = (t - 0.58) / 0.42
            const e = easeInOut(lt)
            const pts = outboundPts[i]
            const idx = Math.min(pts.length - 1, Math.round(e * (pts.length - 1)))
            pos = pts[idx]
            trailPath = pts
            trailHead = idx
          }

          const opacity = interpolate(t, [0, 0.04, 0.96, 1], [0, 1, 1, 0])

          return (
            <g key={`dot${i}`} opacity={opacity}>
              {trailPath &&
                Array.from({ length: 7 }).map((_, k) => {
                  const ti = Math.max(0, trailHead - (k + 1) * 4)
                  const tp = trailPath![ti]
                  return (
                    <circle
                      key={k}
                      cx={tp.x}
                      cy={tp.y}
                      r={11 - k * 1.1}
                      fill={dotColor}
                      opacity={(1 - (k + 1) / 8) * 0.45}
                    />
                  )
                })}

              {phase === 'hold' &&
                (() => {
                  const lt = (t - 0.42) / 0.16
                  const ringR = interpolate(lt, [0, 1], [JR, JR + 60])
                  const ringO = interpolate(lt, [0, 1], [0.7, 0])
                  return (
                    <>
                      <circle cx={JX} cy={JY} r={ringR} fill="none" stroke={dotColor} strokeWidth={3} opacity={ringO} />
                      <circle cx={JX} cy={JY} r={14} fill={dotColor} />
                    </>
                  )
                })()}

              {phase !== 'hold' && <circle cx={pos.x} cy={pos.y} r={12} fill={dotColor} />}
            </g>
          )
        })}
      </svg>
    </AbsoluteFill>
  )
}
