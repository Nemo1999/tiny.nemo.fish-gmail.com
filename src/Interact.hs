{-#LANGUAGE BangPatterns#-}
module Interact
  (
    gameAnimateIO
  )
where
import GameRule
import GameSim
import Player.Instances
import Graphics.Gloss.Interface.IO.Game
import Graphics.Gloss.Data.Color
import Graphics.Gloss.Data.Picture
import Data.Vec2(Vec2(..),scalarMul)
import Data.List.Index
import qualified Util as U

-- Every thing is scaled by 0.1 times on the screen 
scaleFactor :: Float
scaleFactor = 0.1

-- Time = Double defined in GameSim
type World  = Time

vec2Point :: Vec2 -> Point
vec2Point (Vec2 !x !y) = (realToFrac x  * scaleFactor , realToFrac y * scaleFactor)



makePicture :: GameSpec -> [PodState] -> Picture
makePicture (GameSpec _ ckpts) ps =
  let picture = Pictures $ imap drawCheckPoint ckpts ++
                           (zipWith drawPod [blue,blue,red,red]  ps)
      (shiftX,shiftY)  = vec2Point ((-0.5) `scalarMul` U.gameWorldSize)
  in Translate shiftX shiftY picture
    where drawCheckPoint :: Int -> Vec2 -> Picture
          drawCheckPoint n  pos =
            let (x,y) = vec2Point pos
            in 
              Color green $ 
                 Translate x y  $
                 Pictures [Scale 0.2 0.2 $ Text $ show n , ThickCircle (realToFrac U.checkPointRadius*scaleFactor) 5]
          drawPod :: Color -> PodState -> Picture
          drawPod c pod =
            let dir@[(x,y),(tX,tY)] = [vec2Point $ podPosition pod , vec2Point $ podTarget  $ podMovement pod ] 
            
            in
              Color c $
                 Pictures $ (:) (Line dir) $  
                 [Translate x y $ circleSolid (realToFrac U.podForceFieldRadius*scaleFactor)]

turnPerSec :: Double
turnPerSec = 2

gameAnimateIO :: GameSpec -> GameHistory -> IO() 
gameAnimateIO gameSpec gs =
  let
    window = InWindow "pod-race simulation" (1600, 900) (0,0)
    initWorld = 0 :: World
    draw :: World -> IO Picture
    draw time = do
      let ps = gs !! max 0 ((length gs - 1 ) - fromInteger (floor time))
      let psNow = gameSimTime (time - fromIntegral (floor time)) ps
      return $ makePicture gameSpec ps --should use psNow instead
    eventHandler _ = pure
    updateWorld :: Float -> World -> IO World
    updateWorld time w = do
      return (w + (realToFrac time) * turnPerSec)
  in playIO window black 4 initWorld draw eventHandler updateWorld 
    

-- Testing

e1 = ElementaryPlayer ()
e2 = ElementaryPlayer ()

testSim :: Int -> IO [Vec2]
testSim n = sequence $ replicate n testGameSim

testGameSim :: IO Vec2
testGameSim = do
  let gsp = testGsp
  ghis <- runGame (e1,e2) gsp
  return $ podPosition $ head (ghis!!0)

testGsp = GameSpec {gameSLaps = 3, gameSCheckpoints = [Vec2 13479.867410300898 771.2779802449776,Vec2 13991.177029911074 5957.9577506621745,Vec2 11283.183037190614 4051.7698613074967,Vec2 890.6858795864157 65.26211610815757,Vec2 364.6964748594801 8655.346773911324,Vec2 1687.2787736171979 3407.517451010222,Vec2 2219.1046319873317 1212.3349781580753]}
  
test :: IO()
test = do
  let gsp = testGsp
  ghis <- runGame (e1,e2) gsp
  gameAnimateIO gsp ghis
