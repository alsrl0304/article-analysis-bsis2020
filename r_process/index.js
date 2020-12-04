/*
간단한 nodejs HTTP 서버
필요한 곳에 복사해 넣고 실행
*/


const http = require('http');
const fs = require('fs');
const url = require('url');

// 서버 생성
http.createServer( function (request, response) {  
    // URL 뒤에 있는 디렉토리/파일이름 파싱
    var pathname = url.parse(request.url).pathname;

    console.log("Request for " + pathname + " received.");

    // 파일 이름이 비어있다면 index.html 로 설정
    if(pathname=="/"){
        pathname = "/index.html";
    }

    // 파일을 읽기
    fs.readFile(pathname.substr(1), function (err, data) {
        if (err) {
            console.log(err);
            // 파일 없음
            // HTTP Status: 404 : NOT FOUND
            response.writeHead(404, {'Content-Type': 'text/html;encoding=utf8'});
        }else{	
            // 파일 찾음
            
            // Content Type 결정
            const dotoffset = pathname.lastIndexOf('.')
            const mimetype = (dotoffset == -1)
            ? 'text/plain'
            : {
                '.html' : 'text/html',
                '.ico' : 'image/x-icon',
                '.jpg' : 'image/jpeg',
                '.png' : 'image/png',
                '.gif' : 'image/gif',
                '.css' : 'text/css',
                '.js' : 'text/javascript'
                }[ request.url.substr(dotoffset) ];

            // HTTP Status: 200 : OK
            response.writeHead(200, {'Content-Type': mimetype+';encoding=utf8'});	
            
            // 파일을 읽어와서 responseBody 에 작성
            response.write(data.toString());		
        }
        // responseBody 전송
        response.end();
    });   
}).listen(8080);

console.log('Server running at http://127.0.0.1:8080/');