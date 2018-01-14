{-
waymonad A wayland compositor in the spirit of xmonad
Copyright (C) 2017  Markus Ongyerth

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

Reach us at https://github.com/ongy/waymonad
-}
{-# LANGUAGE OverloadedStrings, ApplicativeDo #-}
module Config.Output
    ( OutputConfig (..)
    , Mode (..)
    , modifyOutputConfig
    )
where

import Control.Monad (forM)
import Control.Monad.IO.Class (liftIO)
import Config.Schema
import Data.List (sortOn)
import Data.Map (Map)
import Data.Maybe (listToMaybe)
import Data.Ratio (Ratio, (%))
import Data.Text (Text)
import Foreign.Ptr (Ptr)
import Foreign.Storable

import Graphics.Wayland.WlRoots.Output
import Graphics.Wayland.WlRoots.OutputLayout

import Output (Output (..))
import Utility (whenJust)
import Waymonad (getState)
import Waymonad.Types

import Config.Box (Point (..))
import Waymonad.Main (WayUserConf (..))

import qualified Data.Map as M

data OutputConfig = OutputConfig
    { outName :: Text
    -- This should be a point? or even Box?
    , outPosition :: Maybe (Point Int)
    , outMode :: Maybe Mode
    , outScale :: Maybe Float
    } deriving (Eq, Show)

data Mode = Mode
    { modeCWidth :: Word
    , modeCHeight :: Word
    , modeCRefresh :: Word
    } deriving (Eq, Show)


instance Spec Mode where
    valuesSpec = sectionsSpec "mode" $ do
        width  <- reqSection "width"  "The width of the output"
        height <- reqSection "height" "The height of the output"
        refresh <- reqSection "refresh-rate" "The refresh rate"

        pure $ Mode width height refresh


instance Spec OutputConfig where
    valuesSpec = sectionsSpec "output" $ do
        name <- reqSection "name" "Output name (actually connector)"
        pos <- optSection "position" "The position of the output"
        mode <- optSection "mode" "The mode that should be set for this output"
        scale <- optSection "scale" "The output scale"

        pure OutputConfig
            { outName = name
            , outPosition = pos
            , outMode = mode
            , outScale = fmap fromRational scale
            }


-- Should this be in another file..?

pickMode
    :: Ptr WlrOutput
    -> Maybe Mode
    -> Way vs ws (Maybe (Ptr OutputMode))
-- If there's no config, just pick the "last" mode, it's the native resolution
pickMode output Nothing = liftIO $ do
    modes <- getModes output
    pure $ listToMaybe $ reverse modes
pickMode output (Just cfg) = liftIO $ do
    modes <- getModes output
    paired <- forM modes $ \x -> do
        marshalled <- peek x
        pure (marshalled, x)
    -- First try to find modes that match *exactly* on resolution
    let matches = map snd . sortOn (refreshDist . fst) $ filter (sameResolution . fst) paired
    let ratio = map snd . sortOn (\m -> (resDist $ fst m, refreshDist $ fst m)) $ filter (sameAspect . fst) paired

    -- TODO: Sanitize this
    pure . listToMaybe . reverse $ modes ++ ratio ++ matches
    where   sameResolution :: OutputMode -> Bool
            sameResolution mode =
                fromIntegral (modeWidth mode) == modeCWidth cfg
                && fromIntegral (modeHeight mode) == modeCHeight cfg
            refreshDist :: OutputMode -> Int -- Cast to Int, so we don't get wrapping arithmetic, *should* be big enough!
            refreshDist mode = abs $ fromIntegral (modeRefresh mode) - fromIntegral (modeCRefresh cfg)
            confAspect :: Ratio Word
            confAspect = modeCWidth cfg % modeCHeight cfg
            aspect :: OutputMode -> Ratio Word
            aspect mode = fromIntegral (modeWidth mode) % fromIntegral (modeHeight mode)
            sameAspect :: OutputMode -> Bool
            sameAspect = (==) confAspect . aspect
            resDist :: OutputMode -> Int -- We know it's the same ration, so be lazy here
            resDist mode = abs $ fromIntegral (modeWidth mode) - fromIntegral (modeCWidth cfg)

configureOutput
    :: OutputConfig
    -> Ptr WlrOutput
    -> Way vs a ()
configureOutput conf output = do
    layout <- compLayout . wayCompositor <$> getState
    let position = outPosition conf
        confMode = outMode conf
    mode <- pickMode output confMode

    liftIO $ case position of
        Nothing -> addOutputAuto layout output
        Just (Point x y) -> addOutput layout output x y

    liftIO $ whenJust mode (`setOutputMode` output)
    liftIO $ whenJust (outScale conf) (setOutputScale output)

prependConfig :: Map Text OutputConfig -> (Output -> Way vs ws ()) -> (Output -> Way vs ws ())
prependConfig configs others output = 
    case M.lookup (outputName output) configs of
        Nothing -> others output
        Just conf -> configureOutput conf (outputRoots output)

modifyOutputConfig :: Map Text OutputConfig -> WayUserConf vs ws -> WayUserConf vs ws
modifyOutputConfig m conf = conf { wayUserConfOutputAdd = prependConfig m $ wayUserConfOutputAdd conf }
