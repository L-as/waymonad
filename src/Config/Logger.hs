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
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ApplicativeDo #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}
module Config.Logger
    ( prioritySpec
    , loggerSpec
    , modifyLoggerConfig
    )
where

import Config.Schema
import Data.Functor.Alt ((<!>))
import Data.Maybe (fromMaybe)
import Data.Text (Text)

import Waymonad.Types.Logger (LogPriority(..), WayLoggers (..), Logger (..))
import Waymonad.Main

prioritySpec :: ValueSpec LogPriority
prioritySpec =
    Error <$ atomSpec "Error" <!>
    Warn  <$ atomSpec "Warn" <!>
    Info  <$ atomSpec "Info" <!>
    Debug <$ atomSpec "Debug" <!>
    Trace <$ atomSpec "Trace"

instance HasSpec LogPriority where
    anySpec = prioritySpec

loggerSection :: Text -> Text -> SectionsSpec Logger
loggerSection name desc = flip Logger name . fromMaybe Warn <$> optSection name desc

loggerSpec :: ValueSpec WayLoggers
loggerSpec = sectionsSpec "loggers" (WayLoggers
    <$> loggerSection "Output"  "Output Logger"
    <*> loggerSection "WS"      "WS Logger"
    <*> loggerSection "Focus"   "Focus Logger"
    <*> loggerSection "Xdg"     "Xdg Logger"
    <*> loggerSection "X11"     "X11 Logger"
    <*> loggerSection "Keybinds""Keybinds Logger"
    <*> loggerSection "Spawner" "Spawner Logger"
    <*> loggerSection "Layout"  "Layout Logger"
    <*> loggerSection "Render"  "Render Logger"
    )

instance HasSpec WayLoggers where
    anySpec = loggerSpec

modifyLoggerConfig :: Maybe WayLoggers -> WayUserConf vs ws -> WayUserConf vs ws
modifyLoggerConfig Nothing conf = conf
modifyLoggerConfig (Just loggers) conf =
    conf { wayUserconfLoggers = Just loggers }
