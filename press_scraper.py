##########################################################################
# 특정 언론사 웹 페이지에서 기사 스크랩하는 클래스
##########################################################################


import sys  # 시스템 모듈
import re  # 정규표현식
from functools import reduce  # 고차함수

import requests  # HTTP REQUEST를 위한 모듈
from bs4 import BeautifulSoup  # HTML 분석기

# 브라우저 자동화 도구
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions


class Scraper:
    """
    기사 스크래퍼를 위한 추상 클래스
    """

    CHARACTER_FILTER = re.compile(
        r'[^ 가-힣|a-z|A-Z|0-9|\[|\]|(|)|-|~|?|!|.|,|:|;|%]+')  # 특수 문자나 필요없는 문자들을 제외하기 위한 정규식

    DATE_REGEX = re.compile(
        r'.*((?:19|20)(?:\d{2}))[-.](0[1-9]|1[0-2])[-.]([012][0-9]|3[01]).*')  # 날짜 검출용 정규식

    @staticmethod
    def _extract_date(text):  # 정규식으로 날짜만 분리
        match = re.search(Scraper.DATE_REGEX, text)  # 텍스트에서 정규식 매치
        # 그룹으로 매치된 날짜 (YYYY-MM-DD) 반환
        return f'{match.group(1)}-{match.group(2)}-{match.group(3)}'

    @staticmethod
    def _clean_text(text):  # 필요한 문자만 남기기 위한 함수
        return re.sub(r' +', ' ', Scraper.CHARACTER_FILTER.sub(' ', text))

    @staticmethod
    def _request_get(href):  # HTTP GET 함수
        try:
            response = requests.get(href)  # HTTP GET
            response.encoding = None  # 한글 깨짐을 방지하기 위한 인코딩 자동 변환 방지
            return response
        except requests.exceptions.HTTPError as error:
            print(error)
            sys.exit(1)
        except requests.exceptions.InvalidURL as error:
            print(error)
            sys.exit(1)

    @staticmethod
    def _get_soup(source):  # 링크로 HTTP GET한 HTML문서로부터 BS4 객체를 얻어옴
        return BeautifulSoup(source, 'html.parser')

    # {'href': (링크), 'title': (제목)} 딕셔너리의 리스트 형식으로 반환할것
    def collect_articles(self, number_of_articles, query_word, detail_word):
        raise NotImplementedError

    # {'date': (날짜), 'title': (제목), 'body': (내용)} 딕셔너리로 반환할것
    def scrap_articles(self, article_href):
        raise NotImplementedError


class JoongangScraper(Scraper):
    """
    중앙일보용 스크래퍼
    """

    def collect_articles(self, number_of_articles, query_word, detail_word):
        ARTICLES_PER_PAGE = 10  # 페이지당 기사 수
        article_list = []

        num = 0  # 찾은 기사 수
        for page in range(1, (number_of_articles // ARTICLES_PER_PAGE) + 2):

            soup = Scraper._get_soup(
                Scraper._request_get(
                    f'https://news.joins.com/search/JoongangNews?page={page}&Keyword={query_word}&SortType=New&SearchCategoryType=JoongangNews&IncludeKeyword={detail_word}')
                .text)
            # 중앙일보 웹 서버로 HTTP GET
            # 상세 검색 기능도 함께 이용하여 IncludeKeyword에 명시된 키워드를 포함하는 기사만 검색

            link_elements = soup.select(
                '#content > div.section_news > div.bd > ul > li > div > h2 > a')
            # 검색 결과의 제목과 사이트 주소가 포함되어 있는 부분의 css selector. 이 실렉터로 해당 데이터 가져옴
            # 리스트 형식으로 여러개 반환
            # 검색 결과가 여러 개(중앙일보 사이트는 10개)인 경우 리스트 요소들로부터 하나씩 불러와서 작업하기 위한 반복문

            for element in link_elements:
                if num >= number_of_articles:
                    break
                article = {'href': element.get(
                    "href"), 'title': Scraper._clean_text(element.get_text())}
                article_list.append(article)
                num = num + 1
                print(num, article['href'], sep=': ')

        return article_list

    def scrap_articles(self, article_href):

        soup = Scraper._get_soup(Scraper._request_get(article_href).text)

        # 기사 날짜 추출
        date_element = soup.select(
            'div.article_head > div.clearfx > div.byline > em')[1]  # 최초 일자 요소 (최종 수정일자는 [2]번째 요소)
        date = Scraper._extract_date(
            date_element.get_text())  # 정규식으로 날짜만 얻어옴

        # 기사 제목 추출
        title_element = soup.select('#article_title')[0]  # 기사 제목 요소 추출. 하나뿐임
        title = Scraper._clean_text(title_element.get_text())

        # 기사 본문 추출하는 부분
        body_elements = soup.select(
            '#article_body')  # 기사 내용 요소 추출, 여러개일 수 있음

        body = reduce(lambda prev, next: prev + next,
                      map(lambda element: Scraper._clean_text(element.get_text()), body_elements))  # 각 요소별 내용을 하나로 합침

        # {'date': (날짜), 'title': (제목), 'body': (내용)} 딕셔너리로 반환
        return {'date': date, 'title': title, 'body': body}


class DongaScraper(Scraper):
    """
    동아일보용 스크래퍼
    """

    def __init__(self, path_chromedriver):
        self.path_chromedriver = path_chromedriver

    def collect_articles(self, number_of_articles, query_word, detail_word):
        # 기사 링크만 필터링
        ARTICLE_HREF_FILTER = re.compile(r'.+/news/article/.+')
        ARTICLES_PER_PAGE = 15  # 페이지당 기사 수
        article_list = []

        # Selenium 설정
        options = webdriver.ChromeOptions()  # Chromedriver 옵션
        options.add_argument('headless')  # 헤드리스(GUI 없음) 모드
        options.add_argument('window-size=1920x1080')
        options.add_argument("disable-gpu")
        options.add_argument("--log-level=3")
        driver = webdriver.Chrome(
            self.path_chromedriver, chrome_options=options)

        num = 0  # 찾은 기사 수
        for page in range(0, (number_of_articles // ARTICLES_PER_PAGE) + 1):
            driver.get(
                f'https://www.donga.com/news/search?p={1+page*ARTICLES_PER_PAGE}&query={query_word}&check_news=1&more=1&sorting=1&search_date=1&v1=&v2=&range=1')

            WebDriverWait(driver, 10).until(expected_conditions.presence_of_element_located((
                By.CSS_SELECTOR, '#content > div.searchContWrap > div.searchCont > div.searchList > div.t > p.tit > a')))

            soup = Scraper._get_soup(driver.page_source)

            link_elements = soup.select(
                '#content > div.searchContWrap > div.searchCont > div.searchList > div.t > p.tit > a')  # 검색 결과의 제목과 사이트 주소가 포함되어 있는 부분의 css selector.

            link_elements = list(filter(lambda element: ARTICLE_HREF_FILTER.search(
                element.get("href")), link_elements))  # 기사 링크만 필터링

            for element in link_elements:
                if num >= number_of_articles:
                    break
                article = {'href': element.get(
                    "href"), 'title': Scraper._clean_text(element.get_text())}
                article_list.append(article)
                num = num + 1
                print(num, article['href'], sep=': ')

        return article_list

    def scrap_articles(self, article_href):
        soup = Scraper._get_soup(Scraper._request_get(article_href).text)

        # 기사 날짜 추출
        date_element = soup.select(
            '#container > div.article_title > div.title_foot > span.date01')[0]  # 최초 일자 요소 (최종 수정일자는 [1]번째 요소)
        date = Scraper._extract_date(
            date_element.get_text())  # 정규식으로 날짜만 얻어옴

        # 기사 제목 추출
        title_element = soup.select(
            '#container > div.article_title > h1')[0]  # 기사 제목 요소 추출. 하나임
        title = Scraper._clean_text(title_element.get_text())

        # 기사 본문 추출하는 부분
        body_element = soup.select(
            '#content > div > div.article_txt')[0]  # 기사 내용 요소 추출, 하나임

        body = Scraper._clean_text(body_element.get_text())

        # {'date': (날짜), 'title': (제목), 'content': (내용)} 딕셔너리로 반환
        return {'date': date, 'title': title, 'body': body}

class ChosunScraper(Scraper):
    """
    조선일보용 스크래퍼
    """

    def __init__(self, path_chromedriver):
        self.path_chromedriver = path_chromedriver

    def collect_articles(self, number_of_articles, query_word, detail_word):
        ARTICLES_PER_PAGE = 10  # 페이지당 기사 수
        article_list = []

        # Selenium 설정
        options = webdriver.ChromeOptions()  # Chromedriver 옵션
        options.add_argument('headless')  # 헤드리스(GUI 없음) 모드
        options.add_argument('window-size=1920x1080')
        options.add_argument("disable-gpu")
        options.add_argument("--log-level=3")
        driver = webdriver.Chrome(
            self.path_chromedriver, chrome_options=options)

        driver.get(f'https://www.chosun.com/nsearch/?query={query_word}&siteid=&sort=1&date_period=all&writer=&field=&emd_word={detail_word}&expt_word=&opt_chk=false')
        
        num = 0  # 찾은 기사 수
        for _ in range(number_of_articles // ARTICLES_PER_PAGE + 1):
            if num >= number_of_articles:
                break

            WebDriverWait(driver, 10).until(expected_conditions.presence_of_element_located((
                By.CSS_SELECTOR, '#main > div.search-feed > div > div')))

            soup = Scraper._get_soup(driver.page_source)

            for _ in range(ARTICLES_PER_PAGE): # 한 페이지의 기사 스크랩

                # 검색 결과의 제목과 사이트 주소가 포함되어 있는 부분의 css class
                link_element = soup.select(
                    f'#main > div.search-feed > div:nth-child({num+1}) > div'
                    '> div.story-card.story-card--art-left.\|.flex.flex--wrap.box--hidden-md.box--hidden-lg'
                    '> div.story-card-right.\|.grid__col--sm-9.grid__col--md-9.grid__col--lg-9.box--pad-left-xs'
                    '> div.story-card__headline-container.\|.box--margin-bottom-xs > h3 > a'
                )[0]

                article = {'href': link_element.get("href"), 
                    'title': Scraper._clean_text(link_element.span.get_text())}
                article_list.append(article)
                num = num + 1
                print(num, article['href'], sep=': ')
            
            driver.find_element_by_css_selector('#load-more-stories').click()

        return article_list

    def scrap_articles(self, article_href):
        soup = Scraper._get_soup(Scraper._request_get(article_href).text)

        # 기사 날짜 추출
        date_element = soup.select(
            '#container > div.article_title > div.title_foot > span.date01')[0]  # 최초 일자 요소 (최종 수정일자는 [1]번째 요소)
        date = Scraper._extract_date(
            date_element.get_text())  # 정규식으로 날짜만 얻어옴

        # 기사 제목 추출
        title_element = soup.select(
            '#container > div.article_title > h1')[0]  # 기사 제목 요소 추출. 하나임
        title = Scraper._clean_text(title_element.get_text())

        # 기사 본문 추출하는 부분
        body_element = soup.select(
            '#content > div > div.article_txt')[0]  # 기사 내용 요소 추출, 하나임

        body = Scraper._clean_text(body_element.get_text())

        # {'date': (날짜), 'title': (제목), 'content': (내용)} 딕셔너리로 반환
        return {'date': date, 'title': title, 'body': body}

    


