#!/usr/bin/env stack
{-
    stack
    script
    --resolver lts-13.16
    --package unliftio, transformers
-}
import           Control.Monad.IO.Unlift
import           Control.Monad.Trans.Reader

foo :: (String -> IO ()) -> IO ()
foo func = func "test"

foo2 :: (String -> ReaderT String IO ()) -> ReaderT String IO ()
-- foo2 func = askUnliftIO >>= \u -> liftIO $ foo (unliftIO u . func)
foo2 func = withRunInIO $ \runInIO -> foo (runInIO . func)

myPrint :: String -> ReaderT String IO ()
myPrint string = ReaderT $ \env -> print $ env ++ " " ++ string

main :: IO ()
main = runReaderT (foo2 myPrint) "Environment"
