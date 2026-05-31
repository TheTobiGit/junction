import { Composition } from 'remotion'
import { HeroLoop } from './HeroLoop'

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="hero"
        component={HeroLoop}
        durationInFrames={360}
        fps={60}
        width={1200}
        height={1200}
      />
    </>
  )
}
