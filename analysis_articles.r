#####################################################
# 기사 내용 모음을 받아 그 내용을 분석함
#####################################################

#####################################################
# 명령행 인수 처리
#####################################################

#install.packages('getopt') # 명령행 인수 파서

articlesFileName = NULL 
shouldUseSejongDic = FALSE
shouldInstallPackages = FALSE

# 명령행 인수 파싱 명세
# 각 행은 [옵션명, 짧은 옵션명, 인수 형태(0: 없음, 1: 필수, 2: 선택), 인수 타입, 도움말] 로 구성
argumentSpec = matrix(c( 
    'help', 'h', 0, "logical", "help",
    'install-packages', 'i', 0, 'logical', 'install packages include JDK'
    'article-file', 'a', 1, "character", "filename of scraped article contents"
    'nouns-file', 'n', 1, "character", "filename of filtered common nouns"
    'sejong-dic', 's', 0, "logical", "using sejong dic instead of NIA dic"
), byrow=TRUE, ncol=5)

# 명령행 인수 파싱
commandArgs = getopt(argSpec)

# 도움말 보기
if(!is.null(commandArgs$help)) {
    cat(getopt(argumentSpec, usage=TRUE))
    q(status=1)
}

# 파일명 처리
if(is.null(commandArgs$file)) {
    cat(getopt(argumentSpec, usage=TRUE))
    q(status=1)
} else {
    articlesFileName = commandArgs$file
}

# 세종사전 사용 처리
if(!is.null(commandArgs$(sejong-dic))) {
    shouldUseSejongDic = TRUE
}

# 라이브러리 설치 처리
if(!is.null(commandArgs$(sejong-dic))) {
    shouldInstallPackages = TRUE
}

#####################################################
# 관련 라이브러리 설치                
#####################################################

if(shouldInstallPackages){
    install.packages("rJava")
    install.packages("rmarkdown")
    install.packages('servr')
    install.packages('archivist')
    install.packages('backports')
    install.packages('bit64')
    install.packages("NLP")        #단어 처리를 위한 기본 함수 패키지
    #install.packages("openNLP")   #영어용 추가 기능 공개용 패키지
    #install.packages("KoNLP")     #한국어 처리용 KoNLP 패키지

    install.packages("tm")         #TextMining 패키지
    install.packages("SnowballC")  #Snowball Stemmers 패키지
    install.packages("topicmodels")#Topicmodels 패키지
    install.packages("lda")        #LDA 패키지
    install.packages("ggplot2")    #그래프 출력용 함수 패키지
    install.packages("LDAvis")     #LDA 결과 시각화(visulization)용 패키지
    install.packages("wordcloud")  #wordcloud 패키지
    install.packages('wordcloud2') #wordcloud2 패키지
    install.packages('tidytext')   #tidytext 패키지
    install.packages('Rcpp')       #Rcpp 패키지
    install.packages('slam')       #slam 패키지
    install.packages('rlang')      #rlang 패키지
    install.packages('vctrs')      #vctrs 패키지

    # JAVA 관리
    if(!is.null(Sys.getenv("JAVA_HOME"))) {
        install_jdk()
    }
    install.packages("multilinguer")
    library(multilinguer)
    install.packages(c('stringr', 'hash', 'tau', 'Sejong', 'RSQLite', 'devtools'), type = "binary")
    install.packages("remotes")
    remotes::install_github('haven-jeon/KoNLP', upgrade = "never", force = TRUE, INSTALL_opts=c("--no-multiarch"))
}





#####################################################
# 형태소 분석을 통한 명사 추출
#####################################################

# 필요 라이브러리 로드
library(rJava)
library(KoNLP)
library(NLP)
library(stringr)
library(SnowballC)
library(servr)
library(tm)

# 한국어 형태소 분석에 사용할 사전 선택
if(shouldUseSejongDic){
    useSejongDic() #세종사전 선택 함수
} else {
    useNIADic() #정보화진흥원(NIA) 사전 선택함수
}

articlesFrame <- read.csv(articlesFileName, header = TRUE, fileEncoding = "UTF-8", stringsAsFactors=F)
# 형태소 분석을 위한 수집된 원 데이터 파일 읽어 들임

numOfArticles <- length(articlesFrame[,1])
# 전체 기사의 개수

# 각 기사마다 순회
for(idx in 1:numOfArticles){ 
  vecPos <- SimplePos22(articlesFrame$article[cnt])  # 22가지 품사 구분으로 추출하는 함수
  strPos <- paste(vecPos)
  matMatchedGroup <- str_match(strPos, '([가-힣]+)/NC')  # 모든 한글에 대해서 보통명사만 추출
  vecMatchedStr <- matMatchedGroup[,2]
  listOfNC <- vecMatchedStr[!is.na(vecMatchedStr)]  # 보통명사가 아닌 것을 삭제
  
  line <- ""
  for(word in listOfNC){
    line <- paste(line, listOfNC[cntNC])
  }
  
  articles$article[idx] <- line  # 추출된 보통 명사들을 원 기사 본문 필드에 대체
}

#write.table(articlesFrame, "noun_articles_joongang(corona)(2000).csv", sep=", ", row.names = F, fileEncoding="UTF-8")
# 본문이 추출된 명사로만 이루어진 기사를 다시 저장


#####################################################
# 저빈도수 단어 및 불용어 제거
#####################################################
# 메모리 부족 현상 또는 처리속도 저하 해결하기 위해 
# 분석에 영향을 주지않는 빈도수가 아주 낮은 단어들을 제거함

#articlesFrame <- read.csv("noun_articles_joongang(corona)(2000).csv", header = TRUE, fileEncoding = "UTF-8", stringsAsFactors=F)
# 빈도수가 낮은 단어를 제거하기 위한 파일 읽어 들임

corpusArticles <- VCorpus(VectorSource(articlesFrame$article)) 
# term-document 매트릭스를 만들기 위하여 corpus 구조로 변환

tdmWords <- TermDocumentMatrix(corpusArticles, control=list(wordLengths=c(1, Inf))) 
# 텀-다큐먼트 매트릭스 생성
# TermDocumentMatrix는 기본적으로 두 글자 이상의 단어만 생성에 사용하는 것이 디폴트 옵션임
# 따라서 한글과 같이 한 글자도 의미가 있는 경우에는 control=list(wordLengths=c(1, Inf)) 옵션을
# 사용하여 한 글자 단어도 매트릭스 생성에 포함하기 위한 것임

infrequentWords <- paste(findFreqTerms(tdmWords, 1,2)) #출현 횟수가 1-2회인 단어들을 추출

#출현 횟수가 낮은 단어들을 보통명사들만 저장된 문서들에서 제거하기 위한 루틴
for(word in infrequentWords){
    spaceword <- paste(" ", word, " ", sep="")\
    articles
    articlesFrame$article = gsub(spaceword, " ", articlesFrame$article) 
}

corpusArticles <- VCorpus(VectorSource(articlesFrame$article)) 
# term-document 매트릭스를 만들기 위하여 corpus 구조로 변환

#tdm <- TermDocumentMatrix(corp, control=list(wordLengths=c(1, Inf))) #한 글자 이상 남김

tdmWords <- TermDocumentMatrix(corpusArticles, control=list(wordLengths=c(2, Inf))) #두 글자 이상 남김
# 텀-다큐먼트 매트릭스 생성
# TermDocumentMatrix는 기본적으로 두 글자 이상의 단어만 생성에 사용하는 것이 디폴트 옵션임
# 따라서 한글과 같이 한 글자도 의미가 있는 경우에는 control=list(wordLengths=c(1, Inf)) 옵션을
# 사용하여 한 글자 단어도 매트릭스 생성에 포함하기 위한 것임

matWords <- as.matrix(tdmWords)
# tdm 매트릭스를 단순 2차원 단어-문서(요소값은 단어출현 빈도수) 매트릭스로 변환

# 상위빈도의 단어들만으로 matrix 만들기
wordOrder <- order(rowSums(m), decreasing = T) #빈도가 높은 단어들부터 내림차순 순서를 만듦
row.names(tdmWords[wordOrder[1:500],]) #tdm에서 상위 500개 단어를 확인

source("excluded_words.r", encoding = 'UTF-8') 
#필요없는 단어 제거 명령어가 표함된 excluded_words.r 실행

#write.table(articlesFrame, "ex_rem2_noun_articles_joongang(corona)(2000).csv", sep=", ", row.names = F, fileEncoding="UTF-8")
# 불용어 삭제한 결과 문서를 저장


#####################################################
# 전체 단어 빈도수 분석 및 워드 클라우드 생성 루틴  #
#####################################################
library(wordcloud2)

#articlesFrame <- read.csv("ex_rem2_noun_articles_joongang(corona)(2000).csv", header = TRUE, fileEncoding = "UTF-8", stringsAsFactors=F)
# 빈도 분석과 워드 클라우드 생성을 위한 파일 읽어 들임

corpusArticles <- VCorpus(VectorSource(articlesFrame$article)) 

#tdm <- TermDocumentMatrix(corp, control=list(wordLengths=c(1, Inf))) 
tdmWords <- TermDocumentMatrix(corpusArticles, control=list(wordLengths=c(2, Inf))) 

vecSortedWords <- sort(slam::row_sums(tdm), decreasing = T) 
# tdm을 이용하여 전체 문서에서 단어별 빈도수로 정렬

matWordsFreq <- data.frame(X=names(vecSortedWords),freq=vecSortedWords) 
# 워드 클라우드 출력을 위해 단어와 빈도수로만 된 매트릭스 생성

wordsTop100Freq <- matWordsFreq[1:100,] #상위 100개의 단어를 선택

print(wordsTop100Freq)
# 빈도수 상위 단어 확인용 출력문

#write.table(wordsTop100Freq, "Top100_words(corona)(1000).txt", sep=", ", row.names = F, fileEncoding="UTF-8")
# 상위 100개의 단어를 csv 형태의 파일로 저장

#wordcloud2(wordsTop100Freq) # 선택된 selected로 워드 클라우드 생성
#wordcloud2(wordsTop100Freq, size=1.0, shape = 'star', col="random-dark", rotateRatio = 0)
wordcloud2(wordsTop100Freq, size=0.5, col="random-light", rotateRatio = 0.3, backgroundColor="gray")
# size : 클라우드 크기, col : 글자색상 변경 옵션
# rotateRatio :글자 기울기 허용 각도, backgroundColor : 배경색

# 출력후 오른쪽 하단 메뉴의 Show in new window를 선택하면 독립적인 웹 문서로 생성
# 브라우저에 따라 기본 한글 폰트가 달라지므로 여러 브라우저에 복사해 넣어 보고 좋은 것을 선택


#####################################################
# 토픽수 결정을 위한 perplexity 함수 활용 루틴      #
#####################################################
library(topicmodels) # 토픽 모델링 함수들을 사용하기 위한 라이브러리
library(lda) # LDA 함수를 사용하기 위한 라이브러리

#articlesFrame <- read.csv("ex_rem2_noun_articles_joongang(corona)(2000).csv", header = TRUE, fileEncoding = "UTF-8", stringsAsFactors=F)
# perplexity 함수를 이용한 혼잡도 값을 계산하기 위한 파일 읽어 들임

corpusArticles <- VCorpus(VectorSource(articlesFrame$article)) 
tdmWords <- TermDocumentMatrix(corpusArticles, control=list(wordLengths=c(2, Inf))) 
matWords <- as.matrix(tdmWords)

wordOrder <- order(rowSums(matWords), decreasing = T) 
# 빈도가 높은 단어들부터 순서를 만듦

row.names(tdmWords[wordOrder[1:1000],]) 
# tdm에서 상위 1000개 단어를 확인하는 경우 실행

numForGrouping=500
dtmWordsGroup <- as.DocumentTermMatrix(tdm[wordOrder[1:numForGrouping],])
# 상위 wnum개의 단어로 군집화에 사용될 document-term 매트릭스 생성

set.seed(42135798)
# 랜덤 함수를 위한 초기 시드값 설정

rowTotals <- apply(dtmWordsGroup, 1, sum) 
# 각 문서별로 단어의 총합을 계산하여 저장
ldaDtmWords   <- dtmWordsGroup[rowTotals> 0, ]
# 상위 1000개의 단어를 하나도 포함하고 있지 않는 문서는 삭제함

rlt2 <-""
for(ntopic in 4:15){ # 토픽수를 3개부터 15까지 반복 수행하면서 perplexity 확인
  resultLDAv <- LDA(x = ldadtm, k = ntopic, method = "VEM", 
                    control = list(alpha = 0.01, estimate.alpha = TRUE, 
                                   seed = as.integer(10:1), verbose = FALSE, 
                                   nstart = 10, save = 0, best = TRUE))
  # VEM estimation 방법에 의한 LDA 군집화 수행)(k : 토픽수)
  
  vp <- perplexity(resultLDAv)
  # 지정된 토픽수에 의한 군집화 결과의perplexity 값 산출
  rlt <- paste(ntopic, vp, sep=", ")
  rlt2 <- paste(rlt2, rlt, sep="\n")
  # 반복하면서 토픽수 별로 perplexity 값을 이어 붙이는 기능
}

write.table(rlt2, "perplexity_by_500(4-15).txt", fileEncoding="UTF-8")
#토픽수 별로 저장한 perplexity 값을 파일로 생성


#######################################################
# 결정 토픽수에 따라 Gibbs sampling 방식으로 토픽 추출#
#######################################################
library(topicmodels)
library(lda)

set.seed(42135798)
# 랜덤 함수를 위한 초기 시드값 설정

#articlesFrame <- read.csv("ex_rem2_noun_articles_joongang(corona)(1000).csv", header = TRUE, fileEncoding = "UTF-8", stringsAsFactors=F)

corpusArticles <- VCorpus(VectorSource(articlesFrame$article))
tdmWords <- TermDocumentMatrix(corpusArticles, control=list(wordLengths=c(1, Inf)))
matWords <- as.matrix(tdmWords)


wordOrder <- order(rowSums(matWords), decreasing = T)
# row.names(tdm[wordOrder[1:300],]) 
# tdm에서 상위 300개 단어를 확인

numForGrouping=1000
dtmWordsGroup <- as.DocumentTermMatrix(tdmWords[wordOrder[1:numForGrouping],])
# 상위 wnum개의 단어로 군집화에 사용될 document-term 매트릭스 생성

ldaform <- dtm2ldaformat(dtmWordsGroup, omit_empty = F) 
# dtm을 LDA Gibbs sampler를 위한 형식으로 변환

ntopic = 12  # 결정된 토픽수
result <- lda.collapsed.gibbs.sampler(documents = ldaform$documents,
                                      K = ntopic,     #추출할 토픽의 수
                                      vocab = ldaform$vocab,  #사용할 vocabulary
                                      num.iterations = 5000,  #사후확률의 update 수
                                      burnin = 1000,
                                      alpha = 0.01,     #문서 내에서 토픽들의 확률분포
                                      eta = 0.01)     #한 토픽 내의 단어들의 확률분포
# Gibb sampling에 기반한 LDA 군집화 기법으로 군집화하는 기능

numtopwords=20
# 추출하고자 하는토픽별 빈도수 상위 단어 개수

toptopics <- top.topic.words(result$topics, numtopwords, by.score = T) 
# topic에 대해 빈도가 높은 상위 단어 나열

write.table(t(toptopics), paste("Result_Topics(corona)(1000)", ntopic, "(", numtopwords, ")", ".txt", sep=""), sep=",", row.names = T, fileEncoding="UTF-8")
# topic 별로 빈도가 높은 상위 20개 단어들을 파일로 저장

topic_propotion <- result$topic_sums[,1]/sum(result$topic_sums[,1]) 
# 각 토픽의 비중을 계산

write.table(topic_propotion, paste("Topic_proportion(corona)(1000)", ntopic, "(", numtopwords, ")", ".txt", sep=""), sep=",", row.names = T, fileEncoding="UTF-8")
# 전기간 topic 별 비중을 파일로 저장

str_toptopics <- as.character(toptopics)  
# 토픽에 나온 단어들(토픽별 상위 단어)을 matrix에서 vector로 변환

new_topics <- subset(result$topics, select=str_toptopics)  
# 토픽 결과에서 각 토픽별 상위 단어들의 집합에 대한 부분을 추출
# toptopics는 각 토픽별로 상위 단어들만 갖고 있다면, 
# 이 변수는 각 토픽별로 모든 토픽의 상위 단어들 집합에 대한 출현수를 갖고 있음

newTopicRates <- new_topics / result$topic_sums[,1] 
# 각 topic에 대해 word들의 빈도수를 해당 토픽의 총 word 수로 나눠줌

newTopicRates <- round(newTopicRates, digits = 3) 
# 비율값을 소수점이하 3째 자리로 반올림

write.table(newTopicRates, paste("Topic_Words_Rates(corona)(1000)", ntopic, "(", numtopwords, ")", ".txt", sep=""), sep=",", row.names = T, fileEncoding="UTF-8")
# 토픽별 상위 단어들과 그 비율을 2차원 행렬 형태의 파일로 저장


########################################################
# 여기서부터 기간별로 토픽의 변화를 분석하는 부분      #
########################################################
trends <- as.data.frame(t(result$document_sums), stringAsFactor=F) 
# 기간에 따른 처리의 용이성을 위해 document_sums를 data frame으로 변환 

trends <- trends/rowSums(trends) 
# 전체 값에 대해 rowSum으로 나눠서 비율값으로 변환

nrow(trends)
trends[1:20,]
# 중간 처리 결과를 확인하고자 하는 경우 실행

#trends$date <- substr(articles$adate, 1, 4) 
#adate에서 년도까지만 잘라서 붙임(년도 단위로 추이를 보고자 하는 경우)

#trends$date <- substr(articles$adate, 1, 7) #adate에서 월까지만 잘라서 붙임
#trends$date <- substr(articles$adate, 1, 10) #adate에서 일까지 잘라서 붙임
trends$date <- articles$adate               #원 날짜를 그대로 복사
# 분석하고자 하는 기간 단위에 따라 위에서 택일하여 사용

newtrends <- trends[which(!is.nan(trends$V1)),] 
# trends에서 topic 확률의 값이 NA인 것들을 삭제

newtrends[1:20,]
# 중간 처리 결과를 확인하고자 하는 경우 실행

trends_day <- aggregate(newtrends, by = list(newtrends$date), FUN=mean) 
# 기간별로 평균값 계산

nrow(trends_day)
trends_day
# 중간 처리 결과를 확인하고자 하는 경우 실행

trends_day$date <- NULL
# date에 대한 평균은 의미가 없으므로 삭제

#trends_day <- round(trends_day[2:13], digits = 3)
# 기간별 토픽 비율 값을 소수점 이하 3째 자리로 반올림

write.table(trends_day, paste("trends_by_year(corona)(1000)", ntopic, "(", numtopwords, ")", ".txt", sep=""), sep=",", row.names = F, fileEncoding="UTF-8")
# 기간별 토픽 결과를 파일로 저장
########################################################
# 여기까지 기간별 토픽 변화 추이 처리 완료             #
########################################################


#######################################################
# 결과들을 ggplot 함수에 의해 시각화하는 루틴         #
#######################################################
library(ggplot2)  
#ggplot 관련 함수를 사용하기 위한 라이브러리

p <- ggplot(trends_day, aes(x=Group.1))
# ggplot에 의한 그래프 생성을 위한 객체 p 생성

trends_plot <- p+
  geom_line(aes(y=V1, group=1), color="red", size=2)+
  geom_line(aes(y=V2, group=1), color="black", size=2)+
  geom_line(aes(y=V3, group=1), color="yellow", size=2)+
  geom_line(aes(y=V4, group=1), color="green", size=2)+
  geom_line(aes(y=V5, group=1), color="blue", size=2)+
  geom_line(aes(y=V6, group=1), color="darkblue", size=2)+ 
  geom_line(aes(y=V7, group=1), color="purple", size=2)+
  geom_line(aes(y=V8, group=1), color="magenta", size=2)+
  geom_line(aes(y=V9, group=1), color="gray", size=2)+
  geom_line(aes(y=V10, group=1), color="orange", size=2)+
  geom_line(aes(y=V11, group=1), color="cyan", size=2)+
  geom_line(aes(y=V12, group=1), color="darkgreen", size=2)+
  ylab("Topics")+xlab("")+ggtitle("Topic Trends")

# 토픽의 갯수에 따라 geom_line 부분을 추가

trends_plot # 플롯 결과창에 그래프를 출력
#######################################################
# 결과들을 ggplot 함수에 의해 시각화하는 루틴 끝      #
#######################################################


####################################################### 
# 전 기간에 대한 토픽별 상관 관계 분석 IDM 생성       #
#######################################################
library(topicmodels)
library(lda)

set.seed(42135798)
# 앞서 분석할 때 사용한 초기 시드값을 사용함으로써 
# 새로 수행할 경우 오차가 크게 발생하지 않음

articles <- read.csv("rem2_noun_articles_joongang(corona)(500).csv", header = TRUE, fileEncoding = "UTF-8", stringsAsFactors=F)

corp <- VCorpus(VectorSource(articles$article))
tdm <- TermDocumentMatrix(corp, control=list(wordLengths=c(1, Inf)))
m <- as.matrix(tdm)


wordOrder <- order(rowSums(m), decreasing = T)
# row.names(tdm[wordOrder[1:300],]) 
# tdm에서 상위 300개 단어를 확인

wnum=1000
dtm <- as.DocumentTermMatrix(tdm[wordOrder[1:wnum],])
# 상위 wnum개의 단어로 군집화에 사용될 document-term 매트릭스 생성

ldaform <- dtm2ldaformat(dtm, omit_empty = F) 
# dtm을 LDA Gibbs sampler를 위한 형식으로 변환

ntopic = 12  # 결정된 토픽수
result <- lda.collapsed.gibbs.sampler(documents = ldaform$documents,
                                      K = ntopic,     #추출할 토픽의 수
                                      vocab = ldaform$vocab,  #사용할 vocabulary
                                      num.iterations = 5000,  #사후확률의 update 수
                                      burnin = 1000,
                                      alpha = 0.01,     #문서 내에서 토픽들의 확률분포
                                      eta = 0.01)     #한 토픽 내의 단어들의 확률분포
# Gibb sampling에 기반한 LDA 군집화 기법으로 군집화하는 기능

library(archivist)
# Tools for Storing, Restoring and Searching for R Objects
library(LDAvis) 
# IDM 등의 LDA 결과를 시각화 하는데 필요한 라이브러리

alpha <- 0.01
eta <- 0.01
# 이상 2개의 파라미터 값은 LDA 분석에 사용한 것과 같은 값을 사용하여야
# 새로 처리하는 경우에도 추출되는 토픽별 단어에 큰 변동이 없음

theta <- t(apply(result$document_sums + alpha, 2, function(x) x/sum(x)))
phi <- t(apply(t(result$topics) + eta, 2, function(x) x/sum(x)))

rowTotals <- apply(dtm , 1, sum)
colTotals <- apply(dtm , 2, sum)

# 시각화를 위해 JSON 객체를 생성
json <- createJSON(
  phi = phi, 
  theta = theta, 
  doc.length = rowTotals, 
  vocab = colnames(dtm), 
  term.frequency = colTotals, R=20, lambda.step = 0.01, mds.method = jsPCA)
# R : map에 표시할 토픽별 단어 개수

serVis(json, out.dir = 'IDM(corona)(500)', open.browser =TRUE)
# 생성된 json 파일과 관련 시각화 파일들을 해당 디렉토리에 생성
######################################################## 
# 전 기간에 대한 토픽별 상관 관계 분석 IDM 생성 끝     #
########################################################

