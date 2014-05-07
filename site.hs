--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import           Data.Monoid (mappend)
import           Hakyll


--------------------------------------------------------------------------------
main :: IO ()
main = hakyll $ do
    match "images/*" $ do
        route   idRoute
        compile copyFileCompiler

    match "css/*" $ do
        route   idRoute
        compile compressCssCompiler

    match (fromList ["about.rst", "contact.markdown"]) $ do
        route   $ setExtension "html"
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/default.html" defaultContext
            >>= relativizeUrls
--
--    match "tutorials/*" $ do
--        route $ setExtension "html"
--        compile $ pandocCompiler
--            >>= loadAndApplyTemplate "templates/post.html"    defaultContext
--            >>= loadAndApplyTemplate "templates/default.html" defaultContext
--            >>= relativizeUrls
--
--    create ["archive.html"] $ do
--        route idRoute
--        compile $ do
--            tutorials <- recentFirst =<< loadAll "tutorials/*"
--            let archiveCtx =
--                    listField "tutorials" defaultContext (return tutorials) `mappend`
--                    constField "title" "Archives"            `mappend`
--                    defaultContext
--
--            makeItem ""
--                >>= loadAndApplyTemplate "templates/archive.html" archiveCtx
--                >>= loadAndApplyTemplate "templates/default.html" archiveCtx
--                >>= relativizeUrls

    match "index.html" $ do
        route idRoute
        compile $ do
            tutorials <- recentFirst =<< loadAll "tutorials/*"
            let indexCtx =
                    listField "tutorials" defaultContext (return tutorials) `mappend`
                    constField "title" "Home"                               `mappend`
                    defaultContext

            getResourceBody
                >>= applyAsTemplate indexCtx
                >>= loadAndApplyTemplate "templates/default.html" indexCtx
                >>= relativizeUrls

    match "templates/*" $ compile templateCompiler


--------------------------------------------------------------------------------
--postCtx :: Context String
--postCtx =
--    dateField "date" "%B %e, %Y" `mappend`
--    defaultContext
