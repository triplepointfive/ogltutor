{-# LANGUAGE OverloadedStrings #-}

import Data.Monoid (mappend)
import Control.Monad (liftM)
import System.FilePath (takeFileName)
import Hakyll

main :: IO ()
main = hakyll $ do
    match "images/*" $ do
        route   idRoute
        compile copyFileCompiler

    match "images/logo/*" $ do
        route   idRoute
        compile copyFileCompiler

    match "js/*" $ do
        route   idRoute
        compile copyFileCompiler

    match "css/style.sass" $do
        route   $ gsubRoute "css/" (const "css/") `composeRoutes` setExtension "css"
        compile $ liftM (fmap compressCss) (getResourceString >>= withItemBody (unixFilter "sass" ["-s"]))

    match "css/*.css" $ do
        route   idRoute
        compile compressCssCompiler

    match (fromList ["instr.markdown", "cont.markdown"]) $ do
        route   $ setExtension "html"
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/default.html" defaultContext
            >>= relativizeUrls

    match "tutorials/tutorial1*.markdown" $ do
        route $ setExtension "html"
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/post.html"    postCtx
            >>= loadAndApplyTemplate "templates/default.html" postCtx
            >>= relativizeUrls

    match "index.html" $ do
        route idRoute
        compile $ do
            tutorials <- loadAll "tutorials/*"
            let indexCtx =
                    listField "tutorials" postCtx (return tutorials) `mappend`
                    constField "title" "Home"                        `mappend`
                    defaultContext

            getResourceBody
                >>= applyAsTemplate indexCtx
                >>= loadAndApplyTemplate "templates/default.html" indexCtx
                >>= relativizeUrls

    match "templates/*" $ compile templateCompiler

postCtx :: Context String
postCtx = tutorialNumber `mappend` defaultContext

tutorialNumber :: Context a
tutorialNumber = field "number" ( getNumber . itemIdentifier )

getNumber :: MonadMetadata m => Identifier -> m String
getNumber id' = maybe invalid return $ Just $ take 2 $ drop 8 $ takeFileName $ toFilePath id'
  where
    invalid = fail $ "getNumber: could not number for " ++ show id'