{-# LANGUAGE LambdaCase #-}

-- import Development.Shake
-- import Development.Shake.FilePath

import Haskus.Apps.System.Build.Config
import Haskus.Apps.System.Build.Linux
import Haskus.Apps.System.Build.Syslinux
import Haskus.Apps.System.Build.CmdLine
import Haskus.Apps.System.Build.Utils
import Haskus.Apps.System.Build.Ramdisk
import Haskus.Apps.System.Build.Stack
import Haskus.Apps.System.Build.GMP
import Haskus.Apps.System.Build.QEMU

import qualified Data.Text as Text
import Haskus.Utils.Flow
import Options.Applicative.Simple
import Paths_haskus_system
import Data.Version
import System.IO.Temp
import System.Directory
import System.FilePath
 

main :: IO ()
main = do

   -- read command-line options
   (_,runCmd) <-
      simpleOptions (showVersion version)
                   "haskus-system-build"
                   "This tool lets you build systems using haskus-system framework. It manages Linux/Syslinux (download and build), it builds ramdisk, it launches QEMU, etc."
                   (pure ()) $ do
         addCommand "init"
                   "Create a new project from a template"
                   initCommand
                   initOptions
         addCommand "build"
                   "Build a project"
                   buildCommand
                   buildOptions
         addCommand "test"
                   "Test a project with QEMU"
                   testCommand
                   testOptions
   runCmd

initCommand :: InitOptions -> IO ()
initCommand opts = do
   let
      template = initOptTemplate opts

   cd <- getCurrentDirectory

   withSystemTempDirectory "haskus-system-build" $ \fp -> do
      -- get latest templates
      showStep "Retrieving templates..."
      shellInErr fp "git clone --depth=1 https://github.com/haskus/haskus-system-templates.git" $
         failWith "Cannot retrieve templates. Check that `git` is installed and that github is reachable using https."

      let fp2 = fp </> "haskus-system-templates"
      dirs <- listDirectory fp2
      unless (any (== template) dirs) $
         failWith $ "Cannot find template \"" ++ template ++"\""

      -- copy template
      showStep $ "Copying \"" ++ template ++ "\" template..."
      shellInErr fp2
         ("cp -i -r ./" ++ template ++ "/* " ++ cd) $
            failWith "Cannot copy the selected template"

readConfig :: IO SystemConfig
readConfig = do
   let configFile = "system.yaml"
   
   unlessM (doesFileExist configFile) $
      failWith $ "Cannot find \"" ++ configFile ++ "\""

   mconfig <- readSystemConfig configFile

   case mconfig of
      Nothing -> failWith $ "Cannot parse \"" ++ configFile ++ "\""
      Just c  -> return c

buildCommand :: BuildOptions -> IO ()
buildCommand opts = do
   config' <- readConfig

   -- override config
   let config = if buildOptInit opts /= ""
                  -- TODO: use lenses
                  then config'
                        { ramdiskConfig = (ramdiskConfig config')
                           { ramdiskInit = Text.pack (buildOptInit opts)
                           }
                        }
                  else config'

   showStatus config
   gmpMain
   linuxMain (linuxConfig config)
   syslinuxMain (syslinuxConfig config)
   stackBuild


testCommand :: TestOptions -> IO ()
testCommand opts = do
   config' <- readConfig

   -- override config
   let config = if testOptInit opts /= ""
                  -- TODO: use lenses
                  then config'
                        { ramdiskConfig = (ramdiskConfig config')
                           { ramdiskInit = Text.pack (testOptInit opts)
                           }
                        }
                  else config'

   showStatus config
   gmpMain
   linuxMain (linuxConfig config)
   stackBuild
   ramdiskMain (ramdiskConfig config)
   qemuExecRamdisk config

showStatus :: SystemConfig -> IO ()
showStatus config = do
   let linuxVersion' = Text.unpack (linuxConfigVersion (linuxConfig config))

   let syslinuxVersion' = config
                           |> syslinuxConfig
                           |> syslinuxVersion
                           |> Text.unpack
   let initProgram = config
                           |> ramdiskConfig
                           |> ramdiskInit
                           |> Text.unpack

   ghcVersion    <- stackGetGHCVersion
   stackResolver <- stackGetResolver

   putStrLn "==================================================="
   putStrLn "       Haskus system - build config"
   putStrLn "---------------------------------------------------"
   putStrLn ("GHC version:      " ++ ghcVersion)
   putStrLn ("Stack resolver:   " ++ stackResolver)
   putStrLn ("Linux version:    " ++ linuxVersion')
   putStrLn ("Syslinux version: " ++ syslinuxVersion')
   putStrLn ("Init program:     " ++ initProgram)
   putStrLn "==================================================="


--       -- make disk
--       "_build/disks/**/*.img" %> \out -> do
--          let
--             name    = dropExtension (takeBaseName out)
--             ker     = "_build/linux-"++linuxVersion'++".bin"
--             img     = "_build/ramdisks" </> name <.> ".img"
--             slsrc   = "_sources/syslinux-" ++ syslinuxVersion'
--             syslin  = slsrc </> "bios/core/isolinux.bin"
--             outdir  = takeDirectory (takeDirectory out)
--             bootdir = outdir </> "boot"
--             sldir   = bootdir </> "syslinux"
--             slconf  = sldir </> "syslinux.cfg"
--          need [ker,img,syslin]
--          -- create boot directory
--          unit $ cmd "mkdir" "-p" bootdir
--          unit $ cmd "mkdir" "-p" sldir 
--          -- copy kernel and init disk image
--          unit $ cmd "cp" "-f" ker bootdir
--          unit $ cmd "cp" "-f" img bootdir
--          -- copy syslinux
--          unit $ cmd "find" (slsrc </> "bios")
--                   "-name" "*.c32"
--                   "-exec" "cp" "{}" sldir ";"
--          unit $ cmd "cp" "-f" syslin (sldir </> "isolinux.bin")
--          -- configure syslinux
--          let
--             syslinuxConf =
--                  "DEFAULT main\n\
--                  \PROMPT 0\n\
--                  \TIMEOUT 50\n\
--                  \UI vesamenu.c32\n\
--                  \\n\
--                  \LABEL main\n\
--                  \MENU LABEL MyOS\n\
--                  \LINUX  /boot/" ++ takeBaseName ker ++ ".bin\n\
--                  \INITRD /boot/" ++ name ++ ".img\n\
--                  \APPEND rdinit=" ++ name ++ "\n"
--          liftIO $ writeFile slconf syslinuxConf
-- 
--       -- make ISO image
--       "_build/isos/*.iso" %> \out -> do
--          let
--             name    = dropExtension (takeBaseName out)
--             ker     = "_build/linux-"++linuxVersion'++".bin"
--             img     = "_build/ramdisks" </> name <.> ".img"
--             disk    = "_build/disks"    </> name
--             slsrc   = "_sources/syslinux-" ++ syslinuxVersion'
--             syslin  = slsrc </> "bios/core/isolinux.bin"
--          need [ker,img,syslin, disk </> "boot" </> name <.> "img"]
--          -- create ISO
--          unit $ cmd "mkdir" "-p" "_build/isos"
--          unit $ cmd "xorriso" "-as" "mkisofs" 
--                   "-R" "-J"                         -- use Rock-Ridge/Joliet extensions
--                   "-o" out                          -- output ISO file
--                   "-c" "boot/syslinux/boot.cat"     -- create boot catalog
--                   "-b" "boot/syslinux/isolinux.bin" -- bootable binary file
--                   "-no-emul-boot"                   -- doesn't use legacy floppy emulation
--                   "-boot-info-table"                -- write additional Boot Info Table (required by SysLinux)
--                   "-boot-load-size" "4"
--                   "-isohybrid-mbr" (slsrc </> "bios/mbr/isohdpfx_c.bin")
--                   disk
