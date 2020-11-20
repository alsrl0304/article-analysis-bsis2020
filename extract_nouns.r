#####################################################
# 형태소 분석을 통한 명사 추출 및 저빈도수 단어와 불용어 제거     #
#####################################################

# 라이브러리 로드
library(getopt)
library(rJava)
library(KoNLP)
library(NLP)
library(stringr)
library(SnowballC)
library(servr)
library(tm)

# 명령행 인수 파싱

argSpec <- matrix(c(
  'help', 'h', 0, 'logical', "help",
  'article-file', 'a', 1, 'character', "Input csv files, with scraped articles",
  'filter-file'. 'f'. 1. 'character', "Input text files, with words want to be filtered",
  'result-file', 'r', 1, 'character', "Output csv file, with filtered articles",
  'sejong-dic', 's', 0, 'logical', "Use Sejong-Dic instead of NIA-Dic",
), byrow=TRUE, ncol=5)

opts <- getopt(argSpec)

if (!is.null(opts$help)) {
  cat(getopt(argSpec, usage=TRUE))
  q(status=1)
}

if (is.null(opts$(article-file)) || is.null(opts$(filter-file)) || is.null(opts$(result-file))) {
  cat(getopt(argSpec, usage=TRUE))
  q(status=1)
}

shouldUseSejongDic <- FALSE
if(!is.null(opts$(sejong-dic))) {
  shouldUseSejongDic <- TRUE
}

articleFileName <- opts$(article-file)
filterFileName <- opts$(filter-file)
resultFileName <- opts$(result-file)


###################### 명사 추출 ######################


# 한글 형태소 분석에 사용할 사전 선택
if(shouldUseSejongDic){
  useSejongDic() #세종사전 선택 함수
} else {
  useNIADic() #정보화진흥원(NIA) 사전 선택함수
}

# 형태소 분석을 위한 수집된 원 데이터 파일 읽어 들임
articlesDataFrame <- read.csv(articleFileName, header = TRUE, fileEncoding = "UTF-8", stringsAsFactors=F)

# 전체 기사의 개수
numOfArticles <- length(articlesDataFrame[,1]) 

for (cntArticles in 1:numOfArticles) {
  classifiedVector <- SimplePos22(articlesDataFrame$body[cnt])  # 22가지 품사 구분으로 추출하는 함수
  classifiedStringVector <- paste(classifiedVector)
  nounsVectorWithNA <- str_match(classifiedStringVector, '([가-힣]+)/NC')[,2]  # 모든 한글에 대해서 보통명사만 추출
  nounsVector <- nounsVectorWithNA[!is.na(nounsVectorWithNA)]  # 보통명사가 아닌 것을 삭제
  
  numOfNouns=length(nounsVector)
  
  line <- ""
  for (noun in nounsVector) {
    line <- paste(line, noun)
  }
  
  articlesDataFrame$article[cntArticles] <- line  # 추출된 보통 명사들을 원 기사 본문 필드에 대체
}

################ 저빈도수 단어들을 제거 ###################
# 분석을 위해서는 '문서수 x 단어수' 요소 만큼의 2차원 행렬을 생성하게 됨.
# 이 경우 분석 대상의 문서 수가 방대해지면 추출되는 단어의 갯수도 아주
# 큰 값을 가지게 됨. 그러면 행렬의 요소 수가 수억, 수십억이 넘어가는 
# 경우가 발생하여 메모리 부족 현상 또는 처리속도 저하를 야기할 수 있음.
# 이 문제를 해결하기 위해 분석에 영향을 주지않는 빈도수가 아주 낮은
# 단어들을 제거하는 것이 바람직함.

corpusArticles <- VCorpus(VectorSource(articlesDataFrame$article)) 
# term-document 매트릭스를 만들기 위하여 corpus 구조로 변환

tdmArticles <- TermDocumentMatrix(corpusArticles, control=list(wordLengths=c(1, Inf))) 
# 텀-다큐먼트 매트릭스 생성
# TermDocumentMatrix는 기본적으로 두 글자 이상의 단어만 생성에 사용하는 것이 디폴트 옵션임
# 따라서 한글과 같이 한 글자도 의미가 있는 경우에는 control=list(wordLengths=c(1, Inf)) 옵션을
# 사용하여 한 글자 단어도 매트릭스 생성에 포함하기 위한 것임

infrequentWordsVector <- paste(findFreqTerms(tdmArticles, 1,2)) #출현 횟수가 1-2회인 단어들을 추출

#출현 횟수가 낮은 단어들을 보통명사들만 저장된 문서들에서 제거하기 위한 루틴
for(infrquentWord in infrequentWordsVector) {
  spacedWord <- paste(' ', infrquentWord, ' ', sep="")
  articlesDataFrame$article <- gsub(spacedWord, " ", articlesDataFrame$article)
}


################### 불용어 제거 루틴 ####################

corpusArticles <- VCorpus(VectorSource(articlesDataFrame$article)) 
# term-document 매트릭스를 만들기 위하여 corpus 구조로 변환

#tdm <- TermDocumentMatrix(corp, control=list(wordLengths=c(1, Inf))) #한 글자 이상 남김

tdmArticles <- TermDocumentMatrix(corpusArticles, control=list(wordLengths=c(1, Inf))) 
# 텀-다큐먼트 매트릭스 생성
# TermDocumentMatrix는 기본적으로 두 글자 이상의 단어만 생성에 사용하는 것이 디폴트 옵션임
# 따라서 한글과 같이 한 글자도 의미가 있는 경우에는 control=list(wordLengths=c(1, Inf)) 옵션을
# 사용하여 한 글자 단어도 매트릭스 생성에 포함하기 위한 것임

matArticles <- as.matrix(tdmArticles)
# tdm 매트릭스를 단순 2차원 단어-문서(요소값은 단어출현 빈도수) 매트릭스로 변환

# 상위빈도의 단어들만으로 matrix 만들기
orderedWordVector <- order(rowSums(matArticles), decreasing = T) #빈도가 높은 단어들부터 내림차순 순서를 만듦
row.names(tdmArticles[orderedWordVector[1:500],]) #tdm에서 상위 500개 단어를 확인


# 불용어 제거
filterWordsVector = readLines(filterFileName, encoding='UTF-8')
for (filterWord in filterWordsVector) {
  spacedWord <- paste(' ', infrquentWord, ' ', sep="")
  articlesDataFrame$article = gsub(spacedWord, ' ', articlesDataFrame$article);
}

write.table(articlesDataFrame, resultFileName, sep=", ", row.names = F, fileEncoding="UTF-8")
# 불용어 삭제한 결과 문서를 저장