# article-analysis-bsis2020
Article Analysis RnE Project for Busanil Science High School, 2020 <br>
부산일과학고 2020년 기사 분석 RnE 프로젝트입니다.

## 사용언어 및 라이브러리
- Python 3.x
  - requests
  - BeautifulSoup 4
  - Selenuim (Chromedriver)
- R


## 사용법 
scrap_articles.py [-h] [-p <press>] [-c -n <number> -q <query> -d <detail>] [-s -o <output>] [-l <list>] <br>                                                   
- -h --help: 도움말 <br>
- -p --press [언론] [joongang | donga] <br>
- -c --collect: 기사 목록 검색 <br>
    - -n --number [찾을 기사 수] <br>
    - -q --query [주 검색어] <br>
    - -d --detail [부가 포함 검색어] <br>
    - -l --list   (저장할 파일명) <br>
- -s --scrap 기사 내용 스크랩 <br>
    - -l --list   (기사 목록 파일명) <br>
    - -r --result [출력 파일명] <br><br>
예) scrap_articles.py -p joongang -c -n 100 -q 코로나 -l list.csv
    
