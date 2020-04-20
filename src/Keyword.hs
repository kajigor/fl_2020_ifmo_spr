module Keyword where

import Combinators (Parser (..), Result (..), ErrorMsg (..), InputStream (..), fail', symbol)
import Control.Applicative
import Data.List (sort)

-- Парсер ключевых слов: принимает список ключевых слов,
-- проверяет, что вход начинается с ключевого слова.
-- После ключевого слова во входе должен быть пробельный символ или конец строки.
-- Должен строить по входным ключевым словам либо минимальный автомат, либо бор.
-- Если префикс входа длиной n не является префиксом ни одного входного ключевого слова, чтение n+1-ого символа проводиться не должен.

predErrMsg :: String
predErrMsg = "Predicate failed"

-- Implemented as Trie data structure
keyword :: [String] -> Parser String String String
keyword ks = construct (sort ks) isTerminal

-- Нет никаких ограничений на терминирующий символ ключевого слова
-- Используется для парсинга операторов внутри AST
keywordWeak :: [String] -> Parser String String String
keywordWeak ks = spaces *> construct (sort ks) isTerminalWeak <* spaces where
  spaces = many $ (symbol ' ' <|> symbol '\n' <|> symbol '\t')

construct :: [String] -> Parser String String String -> Parser String String String
construct [] terminalP = fail' predErrMsg
construct ks terminalP = 
  let (lvlIsTerminal, ks') = filterWithFlag (/="") ks
      heads = uniqueOfSorted $ head <$> ks'
      nodes = [(:) <$> symbol h <*>
                construct (tail <$> filter ((==h) . head) ks') terminalP | h <- heads]
      level = nodesAsLevel nodes
      nodesAsLevel :: [Parser String String String] -> Parser String String String
      nodesAsLevel [] = fail' predErrMsg
      nodesAsLevel (x:xs) = foldr (<|>) x xs
  in if lvlIsTerminal then level <|> terminalP else level

-- returns (true,filtered) if any filtering was performed
filterWithFlag :: (a -> Bool) -> [a] -> (Bool, [a])
filterWithFlag pred = foldr step (False, []) where
  step a (cond, acc) = if pred a
                       then (cond, a : acc)
                       else (True, acc)

uniqueOfSorted :: Eq a => [a] -> [a]
uniqueOfSorted [] = []
uniqueOfSorted (x:xs) = go xs x where
  go [] prev = [prev]
  go (x:xs) prev = if x == prev then go xs prev else prev : go xs x

isEmpty :: Parser String String String
isEmpty = Parser $ \input -> case input of
  (InputStream [] pos) -> Success input Nothing []
  (InputStream (x:xs) pos) -> Failure $ Just $ ErrorMsg ["Expecting end of keyword"] pos

isTerminal :: Parser String String String
isTerminal = isEmpty <|> foldr1 (<|>) (terminateWith <$> spaceChars) where
  spaceChars = [' ', '\n', '\t', '\r', '\f']
  terminateWith c = (:) <$> symbol c *> pure ""

isTerminalWeak :: Parser String String String
isTerminalWeak = pure ""
