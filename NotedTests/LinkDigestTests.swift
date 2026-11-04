import XCTest
@testable import Noted

/// Synthetic fixtures only: shapes follow real pages (link-understanding Phase 01), text is invented.
final class LinkDigestTests: XCTestCase {
    private func digest(_ html: String, url: String, redirectedToLogin: Bool = false) -> LinkDigestContent {
        ExtractiveLinkDigester.digest(fields: LinkPageParser.parse(html), url: URL(string: url)!,
                                      redirectedToLogin: redirectedToLogin)
    }

    // MARK: Parser

    func testNewsArticleUsesMetaAndArticleBodyWithoutNavigation() {
        let paragraph = "Giá cà phê Robusta tại Tây Nguyên tăng mạnh trong tuần qua do nguồn cung hạn chế."
        let html = """
        <!doctype html><html><head><title>Giá cà phê tăng - Báo Mẫu</title>
        <meta property="og:title" content="Giá cà phê tăng kỷ lục">
        <meta property="og:site_name" content="Báo Mẫu">
        <meta property="og:description" content="Giá cà phê nhân xô hôm nay tăng thêm 2.000 đồng/kg, lên mức cao nhất từ đầu năm.">
        </head><body><header><p>Trang chủ · Kinh tế · Thể thao · Đăng nhập tài khoản</p></header>
        <nav><p>Menu điều hướng của trang báo mẫu dài hơn hai mươi ký tự</p></nav>
        <article><h1>Giá cà phê tăng kỷ lục</h1><p>\(paragraph)</p><p>Các doanh nghiệp xuất khẩu đang tích cực thu mua.</p></article>
        <aside><p>Tin liên quan: thời tiết hôm nay và nhiều tin khác nữa</p></aside></body></html>
        """
        let fields = LinkPageParser.parse(html)
        XCTAssertEqual(fields.htmlTitle, "Giá cà phê tăng - Báo Mẫu")
        XCTAssertEqual(fields.siteName, "Báo Mẫu")
        XCTAssertTrue(fields.mainText.hasPrefix(paragraph))
        XCTAssertFalse(fields.mainText.contains("Menu"))
        XCTAssertFalse(fields.mainText.contains("Tin liên quan"))
        XCTAssertFalse(fields.mainText.contains("Đăng nhập"))

        let result = digest(html, url: "https://baomau.vn/gia-ca-phe.html")
        XCTAssertEqual(result.status, .complete)
        XCTAssertEqual(result.title, "Giá cà phê tăng kỷ lục")
        XCTAssertEqual(result.siteName, "Báo Mẫu")
        XCTAssertEqual(result.summary, "Giá cà phê nhân xô hôm nay tăng thêm 2.000 đồng/kg, lên mức cao nhất từ đầu năm.")
    }

    func testBlogWithOnlyJSONLDReadsHeadlineAuthorAndDescription() {
        let html = """
        <html><head><title>Pha cold brew tại nhà – Blog Mẫu</title>
        <script type="application/ld+json">
        {"@context":"https://schema.org","@graph":[{"@type":"WebSite","name":"Blog Mẫu"},
         {"@type":"BlogPosting","headline":"Pha cold brew tại nhà","author":[{"@type":"Person","name":"Minh Anh"}],
          "description":"Hướng dẫn pha cold brew bằng bình thủy tinh, ủ lạnh 12 giờ và tỉ lệ 1:8.",
          "articleBody":"Bước một xay cà phê thô. Bước hai ngâm nước lạnh."}]}
        </script></head><body><div id="app"></div></body></html>
        """
        let fields = LinkPageParser.parse(html)
        XCTAssertTrue(fields.hasJSONLD)
        XCTAssertEqual(fields.jsonLD.headline, "Pha cold brew tại nhà")
        XCTAssertEqual(fields.jsonLD.authorName, "Minh Anh")
        XCTAssertEqual(fields.jsonLD.articleBody, "Bước một xay cà phê thô. Bước hai ngâm nước lạnh.")

        let result = digest(html, url: "https://blog.example.org/cold-brew")
        XCTAssertEqual(result.title, "Pha cold brew tại nhà")
        XCTAssertEqual(result.author, "Minh Anh")
        XCTAssertEqual(result.summary, "Hướng dẫn pha cold brew bằng bình thủy tinh, ủ lạnh 12 giờ và tỉ lệ 1:8.")
        XCTAssertTrue(result.textForEmbedding?.contains("Bước một xay cà phê thô.") == true)
    }

    func testEmptySPAIsTitleOnlyAndFallsBackToHost() {
        let withTitle = digest("""
        <html><head><title>Ứng dụng Mẫu</title></head><body><div id="root"></div>
        <noscript>You need to enable JavaScript to run this app. Bạn cần bật JavaScript.</noscript></body></html>
        """, url: "https://app.example.com/x")
        XCTAssertEqual(withTitle.status, .titleOnly)
        XCTAssertEqual(withTitle.title, "Ứng dụng Mẫu")
        XCTAssertNil(withTitle.summary)

        let bare = digest("<html><body><div id=root></div></body></html>", url: "https://app.example.com/x")
        XCTAssertEqual(bare.status, .titleOnly)
        XCTAssertEqual(bare.title, "app.example.com")
    }

    func testICloudNoteWithShortGenericDescriptionIsTitleOnly() {
        let result = digest("""
        <html><head><meta property="og:title" content="Danh sách quán cà phê">
        <meta property="og:description" content="Ghi chú được chia sẻ"></head><body></body></html>
        """, url: "https://www.icloud.com/notes/0abcDEF")
        XCTAssertEqual(result.status, .titleOnly)
        XCTAssertEqual(result.title, "Danh sách quán cà phê")
    }

    func testThreadsPostTitleIsContentAndAuthorIsSeparate() {
        let post = "Hôm nay thử cà phê muối ở Huế. Vị mặn nhẹ, béo, rất hợp buổi sáng! Ai biết quán nào ngon nữa không?"
        let result = digest("""
        <html><head><meta property="og:title" content="Lan Nguyễn (&#064;lan.coffee) on Threads" />
        <meta property="og:description" content="\(post)" /><script>
        """, url: "https://www.threads.com/@lan.coffee/post/ABC123")
        XCTAssertEqual(result.status, .complete)
        XCTAssertEqual(result.author, "Lan Nguyễn (@lan.coffee)")
        XCTAssertEqual(result.siteName, "Threads")
        XCTAssertEqual(result.title, "Hôm nay thử cà phê muối ở Huế. Vị mặn nhẹ, béo, rất hợp buổi sáng!")
        XCTAssertEqual(result.summary, post)
    }

    func testFacebookAndInstagramDescriptionsSplitAuthorAndQuotedContent() {
        let facebook = digest("""
        <meta property="og:title" content="Quán Muối Huế">
        <meta property="og:description" content="1.2K likes, 34 comments - Quán Muối Huế on November 1, 2026: &quot;Menu mới tháng 11: cà phê muối, bạc xỉu dừa.&quot;">
        """, url: "https://m.facebook.com/story.php?id=1")
        XCTAssertEqual(facebook.status, .complete)
        XCTAssertEqual(facebook.author, "Quán Muối Huế")
        XCTAssertEqual(facebook.summary, "Menu mới tháng 11: cà phê muối, bạc xỉu dừa.")
        XCTAssertEqual(facebook.title, "Quán Muối Huế")

        let instagram = digest("""
        <meta property="og:title" content="Lan on Instagram: &quot;Pha phin buổi sáng với hạt Cầu Đất.&quot;">
        <meta property="og:description" content="120 likes, 4 comments - lan.coffee on November 2, 2026: &quot;Pha phin buổi sáng với hạt Cầu Đất.&quot;">
        """, url: "https://www.instagram.com/p/XYZ/")
        XCTAssertEqual(instagram.author, "lan.coffee")
        XCTAssertEqual(instagram.summary, "Pha phin buổi sáng với hạt Cầu Đất.")
        XCTAssertEqual(instagram.title, "Pha phin buổi sáng với hạt Cầu Đất.")
    }

    func testLoginWallHasNoSummaryOrTitle() {
        let threads = digest("""
        <meta property="og:title" content="Threads &#x2022; Log in" />
        <meta property="og:description" content="Join Threads to share ideas, ask questions, post random thoughts, find your people and more. Log in with your Instagram." />
        """, url: "https://www.threads.com/@someone")
        XCTAssertEqual(threads, LinkDigestContent(siteName: "Threads", status: .loginWall))

        let facebook = digest("<title>Facebook</title>", url: "https://www.facebook.com/groups/1/posts/2")
        XCTAssertEqual(facebook.status, .loginWall)

        let redirected = digest("<meta property=\"og:description\" content=\"Một mô tả đủ dài nhưng trang đã chuyển hướng tới đăng nhập.\">",
                                url: "https://www.instagram.com/p/A/", redirectedToLogin: true)
        XCTAssertEqual(redirected.status, .loginWall)
        XCTAssertNil(redirected.summary)
    }

    func testVietnameseEntitiesDecode() {
        XCTAssertEqual(LinkPageParser.decodeEntities("Ti&#7871;ng Vi&#x1EC7;t &agrave; &amp; &nbsp;x &unknown; &#xZZ; &"),
                       "Tiếng Việt à & \u{00A0}x &unknown; &#xZZ; &")
        let fields = LinkPageParser.parse("<title>C&#224; ph&#234; s&#7919;a &#273;&#225;</title>")
        XCTAssertEqual(fields.htmlTitle, "Cà phê sữa đá")
    }

    func testTruncatedOversizedPageStillYieldsHeadMeta() {
        let filler = String(repeating: "<div class=\"x\">\(String(repeating: "y", count: 200))</div>", count: 3_000)
        let html = "<html><head><meta property=\"og:title\" content=\"Bài dài\"><meta property=\"og:description\" " +
            "content=\"Mô tả nằm ở đầu trang dù trang rất lớn và bị cắt.\"></head><body>\(filler)<div class=\"cut"
        XCTAssertGreaterThan(html.utf8.count, LinkMetadataService.maximumBytes)
        let truncated = String(decoding: Array(html.utf8.prefix(LinkMetadataService.maximumBytes)), as: UTF8.self)
        let result = digest(truncated, url: "https://example.org/a")
        XCTAssertEqual(result.title, "Bài dài")
        XCTAssertEqual(result.summary, "Mô tả nằm ở đầu trang dù trang rất lớn và bị cắt.")
    }

    func testMalformedHTMLDoesNotBreakParsing() {
        let html = """
        <HTML><HEAD><!-- <meta property="og:title" content="Từ comment"> --><META NAME=description CONTENT=ngắn>
        <meta property='og:title' content='Tiêu đề thật'></HEAD><BODY>
        <div><P>Đoạn một không đóng thẻ, có dấu < lạc và vẫn đủ dài để tính.<P>Đoạn hai cũng đủ dài để được tính vào.
        <script>var s = "</div><p>không phải nội dung</p>";</script></div>
        <p>Đoạn chưa đóng ở cuối trang khi tài liệu kết thúc đột ngột
        """
        let fields = LinkPageParser.parse(html)
        XCTAssertEqual(fields.ogTitle, "Tiêu đề thật")
        XCTAssertEqual(fields.metaDescription, "ngắn")
        XCTAssertTrue(fields.mainText.contains("Đoạn một không đóng thẻ, có dấu < lạc"))
        XCTAssertTrue(fields.mainText.contains("Đoạn hai cũng đủ dài"))
        XCTAssertFalse(fields.mainText.contains("không phải nội dung"))
    }

    func testDensestParagraphContainerWinsAndBoilerplateSentencesAreSkipped() {
        let html = """
        <div id="sidebar"><p>Liên kết phụ thứ nhất ở cột bên trang.</p></div>
        <div id="content"><p>Chúng tôi dùng cookie để cải thiện trải nghiệm của bạn.</p>
        <p>Rang cà phê ở nhiệt độ thấp giữ được hương trái cây. Thời gian rang khoảng mười hai phút.</p>
        <p>Sau khi rang nên ủ hạt ba ngày trước khi pha để khí CO2 thoát bớt ra ngoài.</p></div>
        """
        let fields = LinkPageParser.parse(html)
        XCTAssertFalse(fields.mainText.contains("cột bên"))
        let result = digest(html, url: "https://rang.example.com/a")
        XCTAssertEqual(result.summary, "Rang cà phê ở nhiệt độ thấp giữ được hương trái cây. Thời gian rang khoảng mười hai phút. " +
                       "Sau khi rang nên ủ hạt ba ngày trước khi pha để khí CO2 thoát bớt ra ngoài.")
    }

    func testDescriptionEqualToTitleFallsBackToMainText() {
        let result = digest("""
        <meta property="og:title" content="Hướng dẫn pha cà phê phin đúng cách cho người mới bắt đầu">
        <meta property="og:description" content="Hướng dẫn pha cà phê phin đúng cách cho người mới bắt đầu">
        <article><p>Tráng phin bằng nước sôi trước, sau đó cho 20 gram cà phê và nén nhẹ.</p></article>
        """, url: "https://example.org/phin")
        XCTAssertEqual(result.summary, "Tráng phin bằng nước sôi trước, sau đó cho 20 gram cà phê và nén nhẹ.")
    }

    // MARK: Text rules

    func testClipKeepsWholeSentencesWithinLimit() {
        let sentences = (1...10).map { "Câu số \($0) nói về cà phê và đủ dài một chút." }.joined(separator: " ")
        let clipped = ExtractiveLinkDigester.clip(sentences, limit: 240)
        XCTAssertLessThanOrEqual(clipped.count, 240)
        XCTAssertTrue(clipped.hasSuffix("."))
        XCTAssertTrue(sentences.hasPrefix(clipped))

        let long = String(repeating: "chữ ", count: 100)
        let cut = ExtractiveLinkDigester.clip(long, limit: 240)
        XCTAssertLessThanOrEqual(cut.count, 240)
        XCTAssertTrue(cut.hasSuffix("chữ…"))
    }

    func testTextForEmbeddingCombinesFieldsAndCapsMainText() {
        let body = (1...80).map { "Đoạn \($0) bàn về nghề barista và thu nhập thêm." }.joined(separator: " ")
        let result = digest("""
        <meta property="og:title" content="Làm barista bán thời gian"><meta property="og:site_name" content="Blog Việc">
        <meta property="og:description" content="Kinh nghiệm làm barista part-time để kiếm thêm thu nhập khi đi học.">
        <article><p>\(body)</p></article>
        """, url: "https://viec.example.com/barista")
        let text = try! XCTUnwrap(result.textForEmbedding)
        XCTAssertTrue(text.hasPrefix("Làm barista bán thời gian\nBlog Việc\nKinh nghiệm làm barista"))
        XCTAssertLessThanOrEqual(text.count, 1_200)
    }

    func testSiteSuffixIsStrippedFromHTMLTitle() {
        XCTAssertEqual(ExtractiveLinkDigester.stripSiteSuffix("Cà phê sáng | Facebook", siteName: nil), "Cà phê sáng")
        XCTAssertEqual(ExtractiveLinkDigester.stripSiteSuffix("lan (@lan) • Instagram photos and videos", siteName: nil), "lan (@lan)")
        XCTAssertEqual(ExtractiveLinkDigester.stripSiteSuffix("Review máy pha - YouTube", siteName: nil), "Review máy pha")
        XCTAssertEqual(ExtractiveLinkDigester.stripSiteSuffix("A - B - Báo Mẫu", siteName: "Báo Mẫu"), "A - B")
        XCTAssertEqual(ExtractiveLinkDigester.stripSiteSuffix("Mua - bán cà phê", siteName: nil), "Mua - bán cà phê")
    }

    func testDomainFamiliesAndLoginURLs() {
        let cases = [
            "https://m.facebook.com/story.php?id=1": "facebook", "https://fb.watch/abc": "facebook",
            "https://www.facebook.com/share/p/xyz/": "facebook", "https://www.instagram.com/p/abc/": "instagram",
            "https://www.threads.net/@a/post/b": "threads", "https://www.threads.com/@a/post/b": "threads",
            "https://youtu.be/x": "youtube", "https://vt.tiktok.com/x": "tiktok",
            "https://vnexpress.net/a.html": "vnexpress.net", "https://news.bbc.co.uk/a": "bbc.co.uk",
            "https://blog.example.com/a": "example.com"
        ]
        for (value, expected) in cases {
            XCTAssertEqual(ExtractiveLinkDigester.domain(for: URL(string: value)!), expected, value)
        }
        XCTAssertTrue(ExtractiveLinkDigester.isLoginURL(URL(string: "https://www.instagram.com/accounts/login/?next=/p/x")!))
        XCTAssertFalse(ExtractiveLinkDigester.isLoginURL(URL(string: "https://www.instagram.com/p/x/")!))
        XCTAssertNotNil(ExtractiveLinkDigester.loginWallPattern(description: "Đăng nhập Facebook để xem bài viết", title: nil))
        XCTAssertNil(ExtractiveLinkDigester.loginWallPattern(description: "Công thức cà phê muối tại nhà", title: "Facebook"))
    }

    /// Regression: the preview title used by `EnrichmentRunner` keeps its exact behavior.
    func testLegacyTitleExtractionIsUnchanged() {
        let url = URL(string: "https://example.com/a")!
        XCTAssertEqual(LinkMetadataService.title(fromHTML: "<TITLE lang=vi>\n  Tom &amp; Jerry &lt;3&gt; &quot;x&quot; &#39;y&#39;\n</TITLE>", url: url),
                       "Tom & Jerry <3> \"x\" 'y'")
        XCTAssertEqual(LinkMetadataService.title(fromHTML: "<html><body>no title</body></html>", url: url), "example.com")
        XCTAssertEqual(LinkMetadataService.title(fromHTML: "<title>" + String(repeating: "a", count: 400) + "</title>", url: url).count, 300)
        // Numeric entities other than &#39; stay encoded in the legacy path (the digest decodes them).
        XCTAssertEqual(LinkMetadataService.title(fromHTML: "<title>C&#224; ph&#234;</title>", url: url), "C&#224; ph&#234;")
    }

    func testParsingLargePageIsFast() {
        let page = "<html><head><meta property=\"og:title\" content=\"x\"></head><body>" +
            String(repeating: "<div><p>Đoạn văn mẫu để đo tốc độ phân tích trang lớn.</p><span>a</span></div>", count: 6_000) + "</body></html>"
        let start = Date()
        _ = LinkPageParser.parse(page)
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
    }
}
