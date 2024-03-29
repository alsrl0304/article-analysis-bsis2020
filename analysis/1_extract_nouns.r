##############################################################
# 형태소 분석을 통한 명사 추출 및 저빈도수 단어와 불용어 제거     #
##############################################################

###################### 명령행 인수 파싱 #######################
library(getopt)
library(tools)

argSpec <- matrix(c(
    'help', 'h', 0, 'logical', "help",
    'input', 'i', 1, 'character', "Scraped Articles, CSV File",
    'filter', 'f', 1, 'character', "Stopwords List, TXT File (Default filter.txt)",
    'output', 'o', 1, 'character', "Extracted Nouns, CSV File (Default nouns_{input}.csv)",
    'sejongdic', 's', 0, 'logical', "Use Sejong Dic instead of NIA Dic"
), byrow=TRUE, ncol=5)

opts <- getopt(argSpec)

if (!is.null(opts$help)) {
    cat(getopt(argSpec, usage=TRUE))
    q(status=1)
}

articlesFileName <- opts$input
filterFileName <- opts$filter
resultFileName <- opts$output

if (is.null(articlesFileName)) {
    cat(getopt(argSpec, usage=TRUE))
    q(status=1)
}

if (is.null(filterFileName)) {
    filterFileName <- "filter.txt"
}

if (is.null(resultFileName)) {
    resultFileName <- paste(paste("nouns", file_path_sans_ext(basename(articlesFileName)), sep="_"), '.csv', sep='')
}

shouldUseSejongDic <- FALSE
if(!is.null(opts$sejongdic)) {
    shouldUseSejongDic <- TRUE
}

###################### 명사 추출 ######################
library(rJava)
library(KoNLP)
library(NLP)
library(stringr)
library(SnowballC)
library(servr)
library(tm)

# 한글 형태소 분석에 사용할 사전 선택
if(shouldUseSejongDic){
    useSejongDic() #세종사전 선택 함수
} else {
    useNIADic() #정보화진흥원(NIA) 사전 선택함수
}

# $date (작성일), $title (제목), $body (기사 본문)
articlesDataFrame <- read.csv(articlesFileName, header = TRUE, fileEncoding = "UTF-8", stringsAsFactors=FALSE)

# 전체 기사의 개수
numOfArticles <- length(articlesDataFrame[,1])

cat("Extract Nouns with", numOfArticles, "Articles.\n", encoding='UTF-8')
cat("Extracting Nouns... ")

for(cntArticle in 1:numOfArticles) {
    cat("\rExtracting Nouns... ", round(cntArticle / numOfArticles * 100), "%", sep='')
    classifiedVector <- SimplePos22(articlesDataFrame$body[cntArticle])  # 22가지 품사 구분으로 추출하는 함수
    classifiedStringVector <- paste(classifiedVector)
    nounsVectorWithNA <- str_match(classifiedStringVector, '([가-힣]+)/NC')[,2]  # 모든 한글에 대해서 보통명사만 추출
    nounsVector <- nounsVectorWithNA[!is.na(nounsVectorWithNA)]  # 보통명사가 아닌 것을 삭제
    
    numOfNouns=length(nounsVector)
    
    line <- ""
    for (noun in nounsVector) {
        line <- paste(line, noun)
    }
    
    articlesDataFrame$body[cntArticle] <- line  # 추출된 보통 명사들을 원 기사 본문 필드에 대체
}

cat("\rExtracting Nouns... [DONE]\n")

################ 저빈도수 단어들을 제거 ###################
# 분석을 위해서는 '문서수 x 단어수' 요소 만큼의 2차원 행렬을 생성하게 됨.
# 이 경우 분석 대상의 문서 수가 방대해지면 추출되는 단어의 갯수도 아주
# 큰 값을 가지게 됨. 그러면 행렬의 요소 수가 수억, 수십억이 넘어가는 
# 경우가 발생하여 메모리 부족 현상 또는 처리속도 저하를 야기할 수 있음.
# 이 문제를 해결하기 위해 분석에 영향을 주지않는 빈도수가 아주 낮은
# 단어들을 제거하는 것이 바람직함.

cat("Removing Infrequent Words... ")

# Corpus 구조로 변환
corpusArticles <- VCorpus(VectorSource(articlesDataFrame$body)) 

# Term-Document Matrix 생성
tdmArticles <- TermDocumentMatrix(corpusArticles, control=list(wordLengths=c(2, Inf))) 

#출현 횟수가 1-2회인 단어들을 추출
infrequentWordsVector <- paste(findFreqTerms(tdmArticles, 1,2)) 

#출현 횟수가 낮은 단어들을 보통명사들만 저장된 문서들에서 제거하기 위한 루틴
done <- 1
total <- length(infrequentWordsVector)
for(infrquentWord in infrequentWordsVector) {
    cat("\rRemoving Infrequent Words... ", round(done / total * 100), "%", sep='')
    spacedWord <- paste(' ', infrquentWord, ' ', sep="")
    articlesDataFrame$body <- gsub(spacedWord, " ", articlesDataFrame$body)
    done <- done + 1
}

cat("\rRemoving Infrequent Words... [DONE]\n")

################### 불용어 제거 루틴 ####################

cat("Removing Stopwords... ")

# 불용어 제거
filterWordsVector <- scan(filterFileName, what="character", fileEncoding='UTF-8')

done <- 1
total <- length(filterWordsVector)
for (filterWord in filterWordsVector) {
    cat("\rRemoving Stopwords... ", round(done / total * 100), "%", sep='')
    spacedFilterWord <- paste(' ', filterWord, ' ', sep="")
    articlesDataFrame$body = gsub(spacedFilterWord, " ", articlesDataFrame$body);
    done <- done + 1
}

cat("\rRemoving Stopwords... [DONE]\n")

# 불용어 삭제한 결과 문서를 저장
write.table(articlesDataFrame, resultFileName, sep=", ", row.names = FALSE, fileEncoding="UTF-8")