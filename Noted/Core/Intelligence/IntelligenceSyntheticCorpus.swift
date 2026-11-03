#if DEBUG
import Foundation

/// Assistant-written evaluation corpus. It never touches library.store and its labels are
/// not user labels, so results from it cannot satisfy the Phase 01 quality gate.
enum IntelligenceSyntheticCorpus {
    static let version = "synthetic-corpus-v1"

    /// Kinds are "text" or "link" only: there are no synthetic images, so Vision is not exercised.
    static func samples() -> [IntelligenceSpikeSample] {
        entries.enumerated().map { index, entry in
            let id = UUID(uuidString: String(format: "5E000000-0000-4000-8000-%012d", index))!
            return IntelligenceSpikeSample(
                id: id, kind: entry.kind, text: entry.text, hasOriginalText: true, imageURL: nil,
                hasOCR: false, gold: entry.topic, desiredTags: [],
                split: IntelligenceLabelStorage.split(for: id))
        }
    }

    private typealias Entry = (topic: String, kind: String, text: String)

    private static let entries: [Entry] = coffee + jobs + carepath + sideIncome + humor + unknown

    private static let coffee: [Entry] = [
        ("Cà phê", "text", "Quán cà phê yên tĩnh ở Quận 3, có ổ cắm, wifi mạnh, mở tới 11 giờ đêm"),
        ("Cà phê", "text", "Cong thuc pha cold brew: 100g ca phe xay tho, 1 lit nuoc, ngam 16 tieng trong tu lanh"),
        ("Cà phê", "link", "highlandscoffee.com.vn\nMenu mùa thu: phin sữa đá, trà sen vàng"),
        ("Cà phê", "text", "Thử hạt Arabica Cầu Đất rang medium, hậu vị chua nhẹ, hợp pha pour over"),
        ("Cà phê", "text", "V60 tỉ lệ 1:15, nước 92 độ, rót 3 lần trong 2 phút 30 giây"),
        ("Cà phê", "link", "instagram.com\nTiệm cà phê sân thượng view hồ Tây, đi buổi chiều đẹp nhất"),
        ("Cà phê", "text", "Cafe trứng Giảng ở Hà Nội, nhớ gọi thêm cacao trứng"),
        ("Cà phê", "text", "OCR: CA PHE MUOI 35.000d  BAC XIU 29.000d  Size L +5k"),
        ("Cà phê", "text", "Máy xay cà phê tay Timemore C3, xay mịn hơn cho espresso"),
        ("Cà phê", "link", "shopee.vn\nPhin nhôm Trung Nguyên combo 2 cái"),
        ("Cà phê", "text", "Best specialty coffee shops in Da Lat: La Viet, Windmill, An cafe"),
        ("Cà phê", "text", "Robusta Buôn Ma Thuột đậm, nhiều caffeine, pha phin truyền thống"),
        ("Cà phê", "text", "Quan cafe chill co meo o Phu Nhuan, cuoi tuan dong nen di som"),
        ("Cà phê", "link", "youtube.com\nHướng dẫn đánh sữa latte art cho người mới"),
        ("Cà phê", "text", "Espresso shot chảy quá nhanh, cần xay mịn hơn và nén chặt tay hơn"),
        ("Cà phê", "text", "OCR: Cafe Phố Cổ - Tầng 4 - Cà phê trứng 40k, view Hồ Gươm"),
        ("Cà phê", "text", "Bạc xỉu là nhiều sữa ít cà phê, khác với nâu đá"),
        ("Cà phê", "link", "foody.vn\nTop 10 quán cà phê làm việc ở Sài Gòn"),
        ("Cà phê", "text", "Pha moka pot trên bếp, lửa nhỏ, nhấc ra khi nghe tiếng xì"),
        ("Cà phê", "text", "Cold brew cam sả, thêm lát cam vàng và vài cọng sả đập dập"),
        ("Cà phê", "text", "Hạt rang để nghỉ 7 ngày rồi mới pha thì ngon hơn"),
        ("Cà phê", "link", "tiktok.com\nCông thức cà phê dừa kiểu Cộng"),
        ("Cà phê", "text", "Quán mới mở gần nhà, cà phê muối ngon, giá 30k"),
        ("Cà phê", "text", "Coffee to water ratio for French press is about 1:12, steep four minutes"),
        ("Cà phê", "text", "Muốn mua máy espresso tầm 5 triệu, xem Delonghi hoặc Breville"),
        ("Cà phê", "text", "Ca phe sua da phai dung sua dac Ong Tho moi dung vi"),
        ("Cà phê", "link", "facebook.com\nGroup review quán cà phê đẹp Sài Gòn"),
        ("Cà phê", "text", "Thử nghiệm cà phê decaf buổi tối để không mất ngủ"),
        ("Cà phê", "text", "OCR: Cafe Rang Xay Nguyen Chat 500g - Robusta Honey"),
        ("Cà phê", "text", "Đi cà phê sáng với bạn ở quán vỉa hè, ly nâu đá 20k")
    ]

    private static let jobs: [Entry] = [
        ("Tìm việc", "link", "itviec.com\nTuyển Senior iOS Developer, lương 3000-4500 USD, remote"),
        ("Tìm việc", "text", "Nộp đơn vị trí Product Designer ở công ty fintech, hạn chót thứ 6"),
        ("Tìm việc", "link", "linkedin.com\nWe are hiring: Backend Engineer (Go), Ho Chi Minh City"),
        ("Tìm việc", "text", "Lịch phỏng vấn vòng 2 lúc 14h thứ Ba, chuẩn bị bài system design"),
        ("Tìm việc", "text", "Tuyen nhan vien marketing part-time, gui CV qua email hr@example.com"),
        ("Tìm việc", "link", "topcv.vn\nViệc làm Data Analyst mới nhất tại Hà Nội"),
        ("Tìm việc", "text", "OCR: JOB DESCRIPTION - Mobile Engineer - Requirements: 3+ years Swift, SwiftUI"),
        ("Tìm việc", "text", "Câu hỏi phỏng vấn thường gặp: điểm mạnh điểm yếu, vì sao rời công ty cũ"),
        ("Tìm việc", "text", "Recruiter nhắn tin về vị trí QA Lead, hẹn gọi điện ngày mai"),
        ("Tìm việc", "link", "vietnamworks.com\nKế toán tổng hợp, lương thỏa thuận"),
        ("Tìm việc", "text", "Đã gửi CV cho 5 công ty tuần này, chờ phản hồi"),
        ("Tìm việc", "text", "Remote job boards: We Work Remotely, RemoteOK, Arc.dev"),
        ("Tìm việc", "text", "Offer letter từ công ty A: lương 35 triệu, thử việc 2 tháng, 13 tháng lương"),
        ("Tìm việc", "link", "glassdoor.com\nInterview questions for Software Engineer at Grab"),
        ("Tìm việc", "text", "Tim viec lam them buoi toi o quan 7, uu tien gan nha"),
        ("Tìm việc", "text", "OCR: TUYỂN DỤNG - Nhân viên bán hàng - Liên hệ 09xx xxx xxx"),
        ("Tìm việc", "text", "Chuẩn bị bài test coding: thuật toán mảng, chuỗi, cây nhị phân"),
        ("Tìm việc", "link", "careerbuilder.vn\nTuyển chuyên viên nhân sự C&B"),
        ("Tìm việc", "text", "Hỏi lương thế nào khi HR hỏi mức lương mong muốn"),
        ("Tìm việc", "text", "Job fair tại Đại học Bách Khoa ngày 15, mang theo 10 bản CV in"),
        ("Tìm việc", "text", "Follow-up email sau phỏng vấn, cảm ơn và nhắc lại sự quan tâm"),
        ("Tìm việc", "link", "itviec.com\nTop công ty IT tuyển fresher năm nay"),
        ("Tìm việc", "text", "Thư từ chối từ công ty B, xin feedback để cải thiện"),
        ("Tìm việc", "text", "Hiring now: Android developer contract 6 months, Kotlin"),
        ("Tìm việc", "text", "OCR: Vong 1: Online test 60 phut. Vong 2: Technical interview. Vong 3: Culture fit"),
        ("Tìm việc", "text", "Tuyển gấp designer freelance cho dự án app, làm full-time 3 tháng"),
        ("Tìm việc", "link", "linkedin.com\nOpen to work: cách bật chế độ tìm việc kín đáo"),
        ("Tìm việc", "text", "Ứng tuyển thực tập sinh kỹ sư phần mềm mùa hè"),
        ("Tìm việc", "text", "Đàm phán offer: xin thêm ngày phép và hỗ trợ laptop"),
        ("Tìm việc", "text", "Danh sách công ty đang tuyển iOS ở Đà Nẵng")
    ]

    private static let carepath: [Entry] = [
        ("Carepath", "text", "Lộ trình từ developer lên tech lead: kỹ năng giao tiếp, review code, mentoring"),
        ("Carepath", "text", "Cập nhật CV: thêm dự án gần nhất, số liệu tác động, bỏ kinh nghiệm cũ"),
        ("Carepath", "link", "medium.com\nHow to get promoted to Staff Engineer"),
        ("Carepath", "text", "Tip AI: dùng ChatGPT viết lại bullet point trong CV theo phương pháp STAR"),
        ("Carepath", "text", "Định hướng 5 năm: chuyển từ mobile sang product management"),
        ("Carepath", "text", "Khoa hoc AWS Solutions Architect giup tang co hoi thang tien"),
        ("Carepath", "link", "coursera.org\nGoogle Project Management Certificate"),
        ("Carepath", "text", "Công cụ AI hỗ trợ công việc: Copilot viết code, Notion AI tóm tắt họp"),
        ("Carepath", "text", "Buổi 1:1 với sếp: hỏi tiêu chí để lên level senior"),
        ("Carepath", "text", "OCR: Career Ladder - L3 Engineer - L4 Senior - L5 Staff - Expectations"),
        ("Carepath", "text", "Xây personal brand trên LinkedIn: viết bài chia sẻ kinh nghiệm mỗi tuần"),
        ("Carepath", "text", "Học tiếng Anh giao tiếp để có cơ hội làm công ty nước ngoài"),
        ("Carepath", "link", "youtube.com\n10 AI tools that will boost your career in 2026"),
        ("Carepath", "text", "Viết mục tiêu OKR cá nhân quý này: hoàn thành chứng chỉ, dẫn dắt 1 dự án"),
        ("Carepath", "text", "Cap nhat portfolio voi case study moi, nhan manh ket qua"),
        ("Carepath", "text", "Mentor khuyên nên học system design trước khi apply senior"),
        ("Carepath", "text", "Prompt hay để luyện phỏng vấn với AI đóng vai interviewer"),
        ("Carepath", "link", "hbr.org\nThe skills managers need to grow their careers"),
        ("Carepath", "text", "Đánh giá năng lực cuối năm: chuẩn bị bằng chứng thành tích"),
        ("Carepath", "text", "Cơ hội nội bộ: team platform đang mở vị trí lead, phù hợp để thăng tiến"),
        ("Carepath", "text", "Sách nên đọc: The Manager's Path, Staff Engineer"),
        ("Carepath", "text", "OCR: Kỹ năng mềm cần có: tư duy phản biện, quản lý thời gian, thuyết trình"),
        ("Carepath", "text", "Dùng Claude để soạn self-review và tổng hợp thành tích quý"),
        ("Carepath", "link", "linkedin.com\nLearning path: từ junior lên senior trong 3 năm"),
        ("Carepath", "text", "Chuyen nganh sang data engineering can hoc SQL, Spark, Airflow"),
        ("Carepath", "text", "Lập kế hoạch học Swift concurrency để nâng level iOS"),
        ("Carepath", "text", "Networking tại meetup công nghệ để mở rộng cơ hội nghề nghiệp"),
        ("Carepath", "text", "Template CV một trang cho kỹ sư phần mềm, font dễ đọc"),
        ("Carepath", "text", "Career growth: ask for stretch projects that show leadership"),
        ("Carepath", "text", "Mục tiêu năm sau: lên senior và tăng lương 20%")
    ]

    private static let sideIncome: [Entry] = [
        ("Kiếm thêm thu nhập", "text", "Bán đồ handmade trên Shopee cuối tuần, lời khoảng 2 triệu/tháng"),
        ("Kiếm thêm thu nhập", "text", "Nhận làm freelance thiết kế logo trên Fiverr"),
        ("Kiếm thêm thu nhập", "link", "upwork.com\nFreelance iOS app projects, hourly rate 40 USD"),
        ("Kiếm thêm thu nhập", "text", "Affiliate marketing: chia sẻ link sản phẩm, nhận hoa hồng 5-10%"),
        ("Kiếm thêm thu nhập", "text", "Day kem tieng Anh online buoi toi, 200k/gio"),
        ("Kiếm thêm thu nhập", "text", "Cho thuê phòng trống qua Airbnb để có thêm thu nhập"),
        ("Kiếm thêm thu nhập", "link", "youtube.com\n7 cách kiếm tiền thụ động cho dân văn phòng"),
        ("Kiếm thêm thu nhập", "text", "Viết blog review sản phẩm, gắn Google AdSense"),
        ("Kiếm thêm thu nhập", "text", "OCR: Thu nhập phụ tháng 10: bán hàng 1.5tr, freelance 3tr, cho thuê xe 800k"),
        ("Kiếm thêm thu nhập", "text", "Làm app nhỏ bán trên App Store, thu phí một lần 2 USD"),
        ("Kiếm thêm thu nhập", "text", "Chạy Grab cuối tuần kiếm thêm tiền xăng"),
        ("Kiếm thêm thu nhập", "text", "Bán khóa học online về Excel trên Udemy"),
        ("Kiếm thêm thu nhập", "link", "tiktok.com\nÝ tưởng kinh doanh nhỏ vốn 5 triệu"),
        ("Kiếm thêm thu nhập", "text", "Đầu tư chứng chỉ quỹ hàng tháng để có thu nhập thụ động"),
        ("Kiếm thêm thu nhập", "text", "Side hustle ideas: print on demand, stock photos, newsletter"),
        ("Kiếm thêm thu nhập", "text", "Ban ca phe online cho ban be, nhap hat tu Dak Lak"),
        ("Kiếm thêm thu nhập", "text", "Nhận dịch tài liệu Anh-Việt, 100k mỗi trang"),
        ("Kiếm thêm thu nhập", "link", "fiverr.com\nTop selling gigs: video editing and voiceover"),
        ("Kiếm thêm thu nhập", "text", "Bán ảnh chụp lên Shutterstock, mỗi lượt tải được vài cent"),
        ("Kiếm thêm thu nhập", "text", "Làm cộng tác viên viết content cho fanpage, trả theo bài"),
        ("Kiếm thêm thu nhập", "text", "OCR: Hoa hồng affiliate tháng này: 1.240.000đ"),
        ("Kiếm thêm thu nhập", "text", "Mở tiệm bánh nhỏ online, nhận order qua Zalo"),
        ("Kiếm thêm thu nhập", "text", "Kiem tien tu YouTube can 1000 sub va 4000 gio xem"),
        ("Kiếm thêm thu nhập", "text", "Dropshipping không cần kho hàng, lấy hàng từ nhà cung cấp"),
        ("Kiếm thêm thu nhập", "text", "Cho thuê lại máy ảnh và ống kính khi không dùng"),
        ("Kiếm thêm thu nhập", "link", "medium.com\nHow I make $500 a month writing online"),
        ("Kiếm thêm thu nhập", "text", "Nhận sửa máy tính tại nhà cho hàng xóm cuối tuần"),
        ("Kiếm thêm thu nhập", "text", "Bán template Notion trên Gumroad"),
        ("Kiếm thêm thu nhập", "text", "Thu nhập thêm từ việc làm gia sư toán lớp 9"),
        ("Kiếm thêm thu nhập", "text", "Ý tưởng: bán nước ép trái cây giao tận văn phòng buổi sáng")
    ]

    private static let humor: [Entry] = [
        ("Hài hước", "text", "Meme: code chạy được mà không biết tại sao, đừng động vào"),
        ("Hài hước", "text", "Thứ Hai đến rồi, con mèo cũng không muốn dậy"),
        ("Hài hước", "link", "facebook.com\nTop 20 ảnh chế hài hước nhất tuần"),
        ("Hài hước", "text", "OCR: Khi sếp nói 'chỉ sửa một chút thôi' 😂"),
        ("Hài hước", "text", "Truyen cuoi: hoc sinh hoi thay giao tai sao 1 cong 1 bang 2"),
        ("Hài hước", "text", "Video chó mèo đánh nhau giành chỗ ngủ, xem cười đau bụng"),
        ("Hài hước", "link", "tiktok.com\nTrend nhảy hài của dân văn phòng"),
        ("Hài hước", "text", "Funny: it works on my machine, ship the machine then"),
        ("Hài hước", "text", "Ảnh chế: lương về như cơn mưa mùa hạ, đến rồi đi rất nhanh"),
        ("Hài hước", "text", "OCR: Tôi lúc 8h sáng vs tôi lúc 5h chiều thứ Sáu"),
        ("Hài hước", "text", "Câu đố vui: con gì càng to càng nhỏ"),
        ("Hài hước", "text", "Joke of the day: why do programmers prefer dark mode? Because light attracts bugs"),
        ("Hài hước", "link", "reddit.com\nr/ProgrammerHumor top posts this week"),
        ("Hài hước", "text", "Mẹ tôi khi thấy tôi cầm điện thoại 5 phút: lại chơi game cả ngày"),
        ("Hài hước", "text", "Meme hai con mèo ngồi bàn ăn la hét nhau"),
        ("Hài hước", "text", "OCR: Đi làm vì đam mê - đam mê có tiền"),
        ("Hài hước", "text", "Clip troll bạn thân bằng hộp quà rỗng"),
        ("Hài hước", "text", "Hai huoc: khi wifi rot dung luc dang nop bai"),
        ("Hài hước", "link", "9gag.com\nFunniest animal fails compilation"),
        ("Hài hước", "text", "Tôi cố gắng ăn kiêng, cái bánh trong tủ lạnh: thử thách bắt đầu"),
        ("Hài hước", "text", "Meme: deadline là động lực mạnh nhất của loài người"),
        ("Hài hước", "text", "OCR: Error 404: Motivation not found"),
        ("Hài hước", "text", "Chuyện vui: ông nội lần đầu dùng video call chỉ thấy trần nhà"),
        ("Hài hước", "text", "Ảnh chú chó đội mũ sinh nhật mặt rất miễn cưỡng"),
        ("Hài hước", "text", "Lol: my code has no bugs, it just develops random features"),
        ("Hài hước", "link", "youtube.com\nTiểu phẩm hài Tết hay nhất"),
        ("Hài hước", "text", "Khi crush seen tin nhắn nhưng không rep"),
        ("Hài hước", "text", "OCR: Ngủ thêm 5 phút - 2 tiếng sau"),
        ("Hài hước", "text", "Meme so sánh kỳ vọng và thực tế khi nấu ăn theo video"),
        ("Hài hước", "text", "Con mèo đẩy ly nước xuống bàn rồi nhìn chủ thản nhiên")
    ]

    /// Includes hard negatives: Java programming, a coffee-named library, generic office talk.
    private static let unknown: [Entry] = [
        ("Không rõ", "text", "Java lập trình hướng đối tượng: class, interface, kế thừa"),
        ("Không rõ", "text", "Công thức nấu phở bò: xương ống, quế, hồi, gừng nướng"),
        ("Không rõ", "link", "booking.com\nKhách sạn Đà Nẵng gần biển Mỹ Khê"),
        ("Không rõ", "text", "Danh sách mua sắm: sữa, trứng, rau muống, nước mắm"),
        ("Không rõ", "text", "Lịch tiêm phòng cho bé tháng 6"),
        ("Không rõ", "text", "CoffeeScript là ngôn ngữ biên dịch sang JavaScript"),
        ("Không rõ", "text", "Mật khẩu wifi nhà bạn: hỏi lại sau"),
        ("Không rõ", "link", "github.com\nawesome-swift: curated list of Swift libraries"),
        ("Không rõ", "text", "Bai tap gym chan: squat 4x10, lunge 3x12"),
        ("Không rõ", "text", "OCR: Hóa đơn điện tháng 10: 450.000đ"),
        ("Không rõ", "text", "Phim nên xem cuối tuần: Interstellar, Inception"),
        ("Không rõ", "text", "Kế hoạch du lịch Sapa 3 ngày 2 đêm"),
        ("Không rõ", "text", "Spring Boot Java bean configuration and dependency injection"),
        ("Không rõ", "link", "wikipedia.org\nLịch sử nhà Nguyễn"),
        ("Không rõ", "text", "Số điện thoại thợ sửa ống nước gần nhà"),
        ("Không rõ", "text", "Cách trồng cây lưỡi hổ trong nhà"),
        ("Không rõ", "text", "OCR: Đơn thuốc: Paracetamol 500mg ngày 2 lần"),
        ("Không rõ", "text", "Review điện thoại mới: pin tốt, camera ổn"),
        ("Không rõ", "text", "Ghi chú họp gia đình về đám cưới em họ"),
        ("Không rõ", "link", "apple.com\niOS 27 release notes"),
        ("Không rõ", "text", "Lich thi dau bong da cuoi tuan"),
        ("Không rõ", "text", "Cách làm bánh flan mềm mịn không rỗ"),
        ("Không rõ", "text", "Nhắc gia hạn bảo hiểm xe máy trước ngày 20"),
        ("Không rõ", "text", "OCR: Vé máy bay HAN-SGN 07:30 cổng 12"),
        ("Không rõ", "text", "Playlist nhạc lofi để ngủ")
    ]
}
#endif
