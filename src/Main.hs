{-# LANGUAGE OverloadedStrings #-}
module Main where

import qualified System.IO.Strict as IO
import System.FilePath (replaceExtension)
import System.Process (system)
import System.IO (stdout, hSetBuffering, BufferMode(LineBuffering))
import Data.Function ((&))
import Data.Monoid ((<>))
import Hakyll

main :: IO ()
main = hakyllWith config $ do
  match "templates/*" $ compile templateCompiler

  match ("css/*.css" .||. "images/*") $ do
    route idRoute
    compile copyFileCompiler

  match ("contact.md" .||. "cv.md")  $ do
    route $ setExtension "html"
    let ctxt = defaultContext
    compile $ pandocCompiler
      >>= applyDefaultTemplate ctxt

  match markdownPostPattern $ do
    route $ setExtension "html"
    compile $ pandocCompiler
      >>= loadAndApplyTemplate "templates/post.html" postCtx
      >>= applyDefaultTemplate postCtx

  match coqPostPattern $ do
    route $ setExtension "html"
    compile $ coqdocCompiler
      >>= loadAndApplyTemplate "templates/post.html" postCtx
      >>= applyDefaultTemplate postCtx

  create ["index.html"] $ do
    route idRoute
    let ctxt =
          listField "posts" postCtx (take 2 <$> getPosts) <>
          defaultContext
    compile $ makeItem ""
      >>= loadAndApplyTemplate "templates/index.html" ctxt
      >>= applyDefaultTemplate ctxt

  create ["archive.html"] $ do
    route idRoute
    let ctxt =
          listField "posts" postCtx getPosts <>
          defaultContext
    compile $ makeItem ""
      >>= loadAndApplyTemplate "templates/archive.html" ctxt
      >>= applyDefaultTemplate ctxt

config :: Configuration
config = defaultConfiguration { deployCommand = "/bin/sh deploy.sh" }

applyDefaultTemplate :: Context String -> Item String -> Compiler (Item String)
applyDefaultTemplate ctx item = item
  & loadAndApplyTemplate "templates/default.html" ctx
  >>= relativizeUrls

markdownPostPattern :: Pattern
markdownPostPattern = "posts/*.md"

coqPostPattern  :: Pattern
coqPostPattern = "posts/*/main.v"

postPattern  :: Pattern
postPattern = markdownPostPattern .||. coqPostPattern

getPosts :: Compiler [Item String]
getPosts = recentFirst =<< loadAll postPattern

postCtx :: Context String
postCtx = dateField "date" "%Y-%m-%d" <> defaultContext

readTmpFile :: FilePath -> Compiler (Item String)
readTmpFile path = unsafeCompiler (IO.readFile path) >>= makeItem

-- I haven't taken the time to learn how to do this idiomatically, if there is such a way.
coqdocCompiler :: Compiler (Item String)
coqdocCompiler = do
  coqPath <- getResourceFilePath
  TmpFile globPath <- newTmpFile ".glob"
  TmpFile htmlPath <- newTmpFile ".html"
  _ <- unsafeCompiler $ do
    hSetBuffering stdout LineBuffering
    putStrLn $ unwords ["html path is:" <> show htmlPath]
    mapM_ (system . unwords)
      [ ["coqc", "-dump-glob", globPath, coqPath]
      , ["rm", replaceExtension coqPath "vo"]
      , ["coqdoc", "-s", "--body-only", "--no-index", "--utf8", "--glob-from", globPath, "--html", "-o", htmlPath, coqPath]]
  readTmpFile htmlPath
