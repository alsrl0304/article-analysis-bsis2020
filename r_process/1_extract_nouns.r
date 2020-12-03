##############################################################
# 형태소 분석을 통한 명사 추출 및 저빈도수 단어와 불용어 제거     #
##############################################################

###################### 명령행 인수 파싱 #######################
library(getopt)
library(tools)

argSpec <- matrix(c(
    'help', 'h', 0, 'logical', "도움말",
    'input', 'i', 1, 'character', "스크래핑한 기사 csv 파일명",
    'filter', 'f', 1, 'character', "제거할 불용어 목록 txt 파일 (기본값 filter.txt)",
    'output', 'o', 1, 'character', "명사 추출한 기사 저장할 csv 파일 (기본값 nouns_{input}.csv)",
    'sejongdic', 's', 0, 'logical', "NIA 사전 대신 세종 사전 사용"
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

cat("\n기사 ", numOfArticles, " 개로 작업 실시.\n", sep="")
cat("\n명사 추출... ")

for(cntArticle in 1:numOfArticles) {
    cat("\r명사 추출... ", round(cntArticle / numOfArticles * 100), "%", sep='')
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

cat("[완료]")

################ 저빈도수 단어들을 제거 ###################
# 분석을 위해서는 '문서수 x 단어수' 요소 만큼의 2차원 행렬을 생성하게 됨.
# 이 경우 분석 대상의 문서 수가 방대해지면 추출되는 단어의 갯수도 아주
# 큰 값을 가지게 됨. 그러면 행렬의 요소 수가 수억, 수십억이 넘어가는 
# 경우가 발생하여 메모리 부족 현상 또는 처리속도 저하를 야기할 수 있음.
# 이 문제를 해결하기 위해 분석에 영향을 주지않는 빈도수가 아주 낮은
# 단어들을 제거하는 것이 바람직함.

cat("\n저빈도수 단어 제거... ")

corpusArticles <- VCorpus(VectorSource(articlesDataFrame$body)) 
# term-document 매트릭스를 만들기 위하여 corpus 구조로 변환

tdmArticles <- TermDocumentMatrix(corpusArticles, control=list(wordLengths=c(1, Inf))) 
# 텀-다큐먼트 매트릭스 생성
# TermDocumentMatrix는 기본적으로 두 글자 이상의 단어만 생성에 사용하는 것이 디폴트 옵션임
# 따라서 한글과 같이 한 글자도 의미가 있는 경우에는 control=list(wordLengths=c(1, Inf)) 옵션을
# 사용하여 한 글자 단어도 매트릭스 생성에 포함하기 위한 것임

infrequentWordsVector <- paste(findFreqTerms(tdmArticles, 1,2)) #출현 횟수가 1-2회인 단어들을 추출

#출현 횟수가 낮은 단어들을 보통명사들만 저장된 문서들에서 제거하기 위한 루틴
done <- 1
total <- length(infrequentWordsVector)
for(infrquentWord in infrequentWordsVector) {
    cat("\r저빈도수 단어 제거... ", round(done / total * 100), "%", sep='')
    spacedWord <- paste(' ', infrquentWord, ' ', sep="")
    articlesDataFrame$body <- gsub(spacedWord, " ", articlesDataFrame$body)
    done <- done + 1
}

cat("[완료]")

################### 불용어 제거 루틴 ####################

cat("\n불용어 제거... ")

corpusArticles <- VCorpus(VectorSource(articlesDataFrame$body)) 
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
orderedWordVector <- order(rowSums(matArticles), decreasing = TRUE) #빈도가 높은 단어들부터 내림차순 순서를 만듦

# 불용어 제거
filterWordsVector <- readLines(filterFileName, encoding='UTF-8')

done <- 1
total <- length(filterWordsVector)
for (filterWord in filterWordsVector) {
    cat("\r불용어 제거... ", round(done / total * 100), "%", sep='')
    spacedFilterWord <- paste(' ', filterWord, ' ', sep="")
    articlesDataFrame$body = gsub(spacedFilterWord, " ", articlesDataFrame$body);
    done <- done + 1
}

cat("[완료]")

# 불용어 삭제한 결과 문서를 저장
write.table(articlesDataFrame, resultFileName, sep=", ", row.names = FALSE, fileEncoding="UTF-8")
cat("\n\n작업 완료.\n")