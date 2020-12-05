##############################################################
# 전체 단어 빈도수 분석                                        #
##############################################################

###################### 명령행 인수 파싱 #######################
library(getopt)
library(tools)

argSpec <- matrix(c(
    'help', 'h', 0, 'logical', "help",
    'input', 'i', 1, 'character', "Extracted Nouns, CSV File",
    'number', 'n', 1, 'integer', "Number of Top Rank Words (Default 25)",
    'output', 'o', 1, 'character', "Most Frequent Words, CSV File (Default frequent_{input}.csv)"
), byrow=TRUE, ncol=5)

opts <- getopt(argSpec)

if(!is.null(opts$help)) {
    cat(getopt(argSpec, usage=TRUE))
    q(status=1)
}

nounsFileName <- opts$input
wordsNum <- opts$number
frequentFileName <- opts$output

if (is.null(nounsFileName)) {
    cat(getopt(argSpec, usage=TRUE))
    q(status=1)
}

if (is.null(wordsNum)) {
    wordsNum <- 25
}

if (is.null(frequentFileName)) {
    frequentFileName <- paste(paste("frequent", 
        file_path_sans_ext(basename(nounsFileName)), sep="_"), ".csv", sep='')
}

######################## 빈도수 분석 ##########################
library(rJava)
library(stringr)
library(SnowballC)
library(servr)
library(tm)

# $date (작성일), $title (제목), $body (기사 본문)
articlesDataFrame <- read.csv(nounsFileName, header = TRUE, fileEncoding = "UTF-8", stringsAsFactors=FALSE)
cat("Select Top", wordsNum, "Words... ")

corpusArticles <- VCorpus(VectorSource(articlesDataFrame$body)) 

# 2음절 이상 단어만 선택해 TDM 생성
tdmArticles <- TermDocumentMatrix(corpusArticles, control=list(wordLengths=c(2, Inf))) 

# TDM을 이용하여 전체 문서에서 단어별 빈도수로 정렬
orderedWordsVector <- sort(slam::row_sums(tdmArticles), decreasing = TRUE) 


# 단어와 빈도수로만 된 매트릭스 생성
frequencyWordsMat <- data.frame(word=names(orderedWordsVector), freq=orderedWordsVector) 

selectedWordsMat <- frequencyWordsMat[1:wordsNum,]

cat("[DONE]\n")

# 상위 단어를 csv 형태의 파일로 저장
write.table(selectedWordsMat, frequentFileName, sep=", ", row.names = FALSE, fileEncoding="UTF-8")