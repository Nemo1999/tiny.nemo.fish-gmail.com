{-# OPTIONS_GHC -O2  #-}
{-# LANGUAGE BangPatterns#-}
{-# LANGUAGE PatternGuards #-}
-- module Warrier.Weapons where

{-
import Util
import Data.Vec2
import GameSim
-- import GameRule
import Player
import Player.GA
-}

import Data.Array.IO
import Data.Maybe
import Data.Function
import Data.List
import System.Random
import System.IO
import Control.Monad
import System.Timeout
import System.CPUTime
import Debug.Trace
--import Control.Parallel

----------------Warrier Start------------------------
type Ckpts = [Vec2]

readPoint :: IO Vec2
readPoint = do
  [x,y] <- fmap (map read) $ words<$>getLine :: IO [Double]
  return $ Vec2 x y

readCkpts :: IO (Int , Ckpts)
readCkpts = do
  laps <- read<$>getLine :: IO Int
  ckptCount <- read<$>getLine :: IO Int 
  ckpts <- sequence $ replicate ckptCount readPoint
  return (laps,ckpts)

readPod   :: (Int , Ckpts)-> IO PodState
readPod  (laps, ckpts)= do
  [x,y,vx,vy,angle,ckptId] <- fmap (map read) $  words<$>getLine :: IO [ Int ]
  let pos = Vec2 (fromIntegral x) (fromIntegral y)
  let speed = Vec2 (fromIntegral vx) ( fromIntegral vy)
  let ang = Nothing -- Just $ fromIntegral angle ?
  let podCkpts = take (laps*length ckpts) (tail $ cycle ckpts)
  return emptyPodState{podPosition=pos,podSpeed=speed,podAngle=ang,podNextCheckPoints=podCkpts}

updatePod :: Ckpts -> PodState -> IO PodState
updatePod ckpts podPrev = do
  [x,y,vx,vy,degree,ckptId] <- fmap (map read) $  words<$>getLine :: IO [ Int ]
  let pos = Vec2 (fromIntegral x) (fromIntegral y)
  let speed = Vec2 (fromIntegral vx) ( fromIntegral vy)
  let ang = Just $ degToRad $fromIntegral degree
  let podCkpts = dropWhile (/= (ckpts!!ckptId)) (podNextCheckPoints podPrev)
  return podPrev{podPosition=pos ,podSpeed = speed , podAngle = ang,podNextCheckPoints=podCkpts}
        
updateShieldThrust :: PodState -> PodState
updateShieldThrust ps@PodState{podBoostAvail=ba,podShieldState=sh,podMovement=(PodMovement _ boost)} =
  let sh' = shieldNextState (boost==Shield) sh
      ba' = if ba then (boost /= Boost) else ba
  in  ps{podBoostAvail = ba',podShieldState = sh'}

putMovement :: PodMovement -> IO ()
putMovement (PodMovement (Vec2 x y) thrust) =
  let xI = round x :: Int
      yI = round y :: Int
      thrustStr = case thrust of
        Boost -> "BOOST"
        Shield -> "SHIELD"
        Normal n -> show n
  in  putStrLn (show xI ++ " " ++ show yI ++ " " ++ thrustStr) 

logStr :: String -> IO ()
logStr = hPutStrLn stderr

gameCycles :: (PlayerIO p) => Ckpts -> [PodState]-> p -> IO ()
gameCycles ckpts [p1,p2,o1,o2] player = do
   [p1',p2',o1',o2'] <- sequence $ map (updatePod ckpts) [p1,p2,o1,o2]
   
   let playerIn = PlayerIn [p1',p2'] [o1',o2']
   
   ([move1,move2] , player') <- playerRunIO player playerIn
   
   let (p1'' ,p2'')= (p1'{podMovement = move1} ,p2'{podMovement=move2})
   
   let [p1''',p2'''] = map updateShieldThrust [p1'',p2'']
   
   putMovement move1
   putMovement move2
   gameCycles ckpts [p1''',p2''',o1',o2'] player'



   
main :: IO ()
main = do
    hSetBuffering stdout NoBuffering -- DO NOT REMOVE

    
    cInfo@(laps,ckpts) <- readCkpts
    pod1  <- readPod cInfo
    pod2  <- readPod cInfo
    opp1  <- readPod cInfo
    opp2  <- readPod cInfo
    
    player <- playerInitIO $ GASimple--WrapIO $  ElementaryPlayer ()
    let playerIn = PlayerIn [pod1,pod2] [opp1,opp2]
    ([move1,move2] , player' )  <- playerRunIO player playerIn
    let (pod1' ,pod2')= (pod1{podMovement = move1} ,pod2{podMovement=move2})
    let [podStart1,podStart2] = map updateShieldThrust [pod1',pod2']
    putMovement move1
    putMovement move2
    -- game loop
    gameCycles ckpts [podStart1,podStart2,opp1,opp2] player'