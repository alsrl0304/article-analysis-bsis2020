##############################################################
# Gibbs Sampling 수행                                        #
##############################################################

####################### 명령행 인수 처리 ######################
library(getopt)
library(tools)

argSpec <- matrix(c(
    'help', 'h', 0, 'logical', "help",
    'input', 'i', 1, 'character', "Extracted Nouns, CSV File",
    'number', 'n', 1, 'integer', "Number of Top Rank Words to Use (Default 500)",
    'topics', 't', 1, 'integer', "Decided Number of Topics",
    'topic-coherence', 'T', 1, 'character', "Coherence Result, CSV File to Decide Number of Topics",
    'output', 'o', 1, 'character', "Trained Gibbs Sampling Model, RData File (Default gibbs_{topic-num}_{input}.RData)"
), byrow=TRUE, ncol=5)

opts <- getopt(argSpec)

if (!is.null(opts$help)) {
    cat(getopt(argSpec, usage=TRUE))
    q(status=1)
}

nounsFileName <- opts$input
wordsNum <- opts$number
numOfTopics <- opts$topics
coherenceFileName <- opts$`topic-coherence`
modelFileName <- opts$output

if (is.null(nounsFileName)) {
    cat(getopt(argSpec, usage=TRUE))
    q(status=1)
}

# 토픽 수 결정
if (is.null(numOfTopics) && is.null(coherenceFileName)) {
    cat(getopt(argSpec, usage=TRUE))
    q(status=1)
} else if (is.null(numOfTopics)) {
    # Coherence가 최솟값인 토픽 수를 사용
    coherenceDataFrame <- read.csv(coherenceFileName, header = TRUE, fileEncoding = "UTF-8", stringsAsFactors=FALSE)
    numOfTopics = coherenceDataFrame[which.max(coherenceDataFrame$coherence),]$topics
}

if(is.null(wordsNum)) {
    wordsNum <- 500
}

if (is.null(modelFileName)) {
    modelFileName <- paste(paste("gibbs", numOfTopics,
        file_path_sans_ext(basename(nounsFileName)), sep="_"), ".RData", sep='')
}

##################### Gibbs Sampling 수행 ####################
library(rJava)
library(stringr)
library(SnowballC)
library(servr)
library(tm)
library(topicmodels)
library(lda)

# 랜덤 함수를 위한 초기 시드값 설정
set.seed(42135798)

# Gibbs Sampling을 위한 파일 읽어 들임
# $date (작성일), $title (제목), $body (기사 본문)
articlesDataFrame <- read.csv(nounsFileName, header = TRUE, fileEncoding = "UTF-8", stringsAsFactors=FALSE)
cat("Training Models by", numOfTopics, "\bTopics.\n")

cat("Generating LDA Form Data... ")
corpusArticles <- VCorpus(VectorSource(articlesDataFrame$body))
tdmArticles <- TermDocumentMatrix(corpusArticles, control=list(wordLengths=c(2, Inf)))
matArticles <- as.matrix(tdmArticles)

orderedWordsVector <- order(rowSums(matArticles), decreasing = TRUE)

# 상위 wordsNum개의 단어로 군집화에 사용될 document-term 매트릭스 생성
dtmArticles <- as.DocumentTermMatrix(tdmArticles[orderedWordsVector[1:wordsNum],])

# DTM을 LDA Gibbs sampler를 위한 형식으로 변환
ldaFormArticles <- dtm2ldaformat(dtmArticles, omit_empty = FALSE) 

cat("[DONE]\n")

cat("Performing Gibbs Sampling... ")

gibbs_alpha = 0.01
gibbs_eta = 0.01

# Gibb sampling에 기반한 LDA 군집화 기법으로 군집화하는 기능
gibbsResult <- lda.collapsed.gibbs.sampler(documents = ldaFormArticles$documents,
                                      K = numOfTopics,     #추출할 토픽의 수
                                      vocab = ldaFormArticles$vocab,  #사용할 vocabulary
                                      num.iterations = 5000,  #사후확률의 update 수
                                      burnin = 1000,
                                      alpha = 0.01,     #문서 내에서 토픽들의 확률분포
                                      eta = 0.01)     #한 토픽 내의 단어들의 확률분포
cat("[DONE]\n")

save(articlesDataFrame, wordsNum, gibbsResult, gibbs_alpha, gibbs_eta, file=modelFileName)