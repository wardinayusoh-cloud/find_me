<?php

header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

include "db.php";


// =====================================================
// ฟังก์ชันส่ง JSON
// =====================================================

function response($success, $message, $data = null)
{
    echo json_encode([
        "success" => $success,
        "message" => $message,
        "data" => $data
    ], JSON_UNESCAPED_UNICODE);

    exit;
}


// =====================================================
// รับ action
// =====================================================

$action = $_GET["action"] ?? "";

// =====================================================
// ตรวจสิทธิ์ Admin (ต้องส่ง admin_id มากับคำขอ)
// =====================================================

function requireAdmin($conn)
{
    $admin_id = intval($_REQUEST["admin_id"] ?? 0);

    $stmt = $conn->prepare(
        "SELECT id FROM users WHERE id = ? AND role = 'admin'"
    );

    $stmt->bind_param("i", $admin_id);
    $stmt->execute();

    if ($stmt->get_result()->num_rows == 0) {

        response(false, "ไม่มีสิทธิ์ใช้งานส่วนของ Admin");
    }
}



// =====================================================
// 1. REGISTER
// =====================================================

if ($action == "register") {

    $username  = $_POST["username"] ?? "";
    $password  = $_POST["password"] ?? "";
    $full_name = $_POST["full_name"] ?? "";
    $email     = $_POST["email"] ?? "";
    $phone     = $_POST["phone"] ?? "";

    if (
        empty($username) ||
        empty($password) ||
        empty($full_name)
    ) {
        response(false, "กรุณากรอกข้อมูลให้ครบ");
    }


    // ตรวจสอบ Username ซ้ำ

    $check = $conn->prepare(
        "SELECT id
         FROM users
         WHERE username = ?"
    );

    $check->bind_param(
        "s",
        $username
    );

    $check->execute();

    $result = $check->get_result();

    if ($result->num_rows > 0) {

        response(
            false,
            "Username นี้มีผู้ใช้งานแล้ว"
        );
    }


    // Hash Password

    $hashedPassword = password_hash(
        $password,
        PASSWORD_DEFAULT
    );


    // เพิ่ม User

    $stmt = $conn->prepare(
        "INSERT INTO users
        (
            username,
            password,
            full_name,
            email,
            phone,
            role
        )
        VALUES
        (
            ?,
            ?,
            ?,
            ?,
            ?,
            'user'
        )"
    );

    $stmt->bind_param(
        "sssss",
        $username,
        $hashedPassword,
        $full_name,
        $email,
        $phone
    );


    if ($stmt->execute()) {

        response(
            true,
            "สมัครสมาชิกสำเร็จ",
            [
                "user_id" => $stmt->insert_id
            ]
        );

    } else {

        response(
            false,
            "สมัครสมาชิกไม่สำเร็จ: " . $stmt->error
        );
    }
}


// =====================================================
// 2. LOGIN
// =====================================================

if ($action == "login") {

    $username = $_POST["username"] ?? "";
    $password = $_POST["password"] ?? "";

    if (
        empty($username) ||
        empty($password)
    ) {

        response(
            false,
            "กรุณากรอก Username และ Password"
        );
    }


    $stmt = $conn->prepare(
        "SELECT *
         FROM users
         WHERE username = ?"
    );

    $stmt->bind_param(
        "s",
        $username
    );

    $stmt->execute();

    $result = $stmt->get_result();


    if ($result->num_rows == 0) {

        response(
            false,
            "ไม่พบ Username นี้"
        );
    }


    $user = $result->fetch_assoc();


    // ตรวจสอบ Password

    if (
        !password_verify(
            $password,
            $user["password"]
        )
    ) {

        response(
            false,
            "Password ไม่ถูกต้อง"
        );
    }


    // ไม่ส่ง Password กลับ Flutter

    unset($user["password"]);


    response(
        true,
        "เข้าสู่ระบบสำเร็จ",
        $user
    );
}


// =====================================================
// 3. GET CATEGORIES
// =====================================================

if ($action == "categories") {

    $sql = "
        SELECT *
        FROM categories
        ORDER BY name ASC
    ";

    $result = $conn->query($sql);

    $categories = [];


    while ($row = $result->fetch_assoc()) {

        $categories[] = $row;
    }


    response(
        true,
        "ดึงหมวดหมู่สำเร็จ",
        $categories
    );
}


// =====================================================
// 4. GET ITEMS
// ค้นหารายการของหาย / ของพบ
// =====================================================

if ($action == "items") {

    $keyword = $_GET["keyword"] ?? "";
    $type    = $_GET["type"] ?? "";
    $status  = $_GET["status"] ?? "";


    $sql = "
        SELECT
            items.*,

            users.full_name,

            categories.name AS category_name

        FROM items

        INNER JOIN users
            ON items.user_id = users.id

        INNER JOIN categories
            ON items.category_id = categories.id

        WHERE 1=1
    ";


    $params = [];
    $types = "";


    // ค้นหา

    if (!empty($keyword)) {

        $sql .= "
            AND
            (
                items.item_name LIKE ?
                OR items.description LIKE ?
                OR items.location LIKE ?
                OR items.color LIKE ?
            )
        ";

        $search = "%" . $keyword . "%";

        $params[] = $search;
        $params[] = $search;
        $params[] = $search;
        $params[] = $search;

        $types .= "ssss";
    }


    // lost / found

    if (!empty($type)) {

        $sql .= "
            AND items.type = ?
        ";

        $params[] = $type;

        $types .= "s";
    }


    // status

    if (!empty($status)) {

        $sql .= "
            AND items.status = ?
        ";

        $params[] = $status;

        $types .= "s";
    }


    $sql .= "
        ORDER BY items.created_at DESC
    ";


    $stmt = $conn->prepare($sql);


    if (count($params) > 0) {

        $stmt->bind_param(
            $types,
            ...$params
        );
    }


    $stmt->execute();

    $result = $stmt->get_result();

    $items = [];


    while ($row = $result->fetch_assoc()) {

        $items[] = $row;
    }


    response(
        true,
        "ดึงรายการสำเร็จ",
        $items
    );
}


// =====================================================
// 5. GET ITEM DETAIL
// =====================================================

if ($action == "item_detail") {

    $id = $_GET["id"] ?? 0;


    $stmt = $conn->prepare(
        "SELECT

            items.*,

            users.full_name,
            users.phone,

            categories.name AS category_name

         FROM items

         INNER JOIN users
            ON items.user_id = users.id

         INNER JOIN categories
            ON items.category_id = categories.id

         WHERE items.id = ?"
    );


    $stmt->bind_param(
        "i",
        $id
    );

    $stmt->execute();

    $result = $stmt->get_result();


    if ($result->num_rows == 0) {

        response(
            false,
            "ไม่พบรายการ"
        );
    }


    $item = $result->fetch_assoc();


    response(
        true,
        "ดึงรายละเอียดสำเร็จ",
        $item
    );
}


// =====================================================
// 6. ADD ITEM
// ใช้สำหรับเพิ่มของหาย / ของพบ
// =====================================================

if ($action == "add_item") {

    $user_id         = $_POST["user_id"] ?? 0;
    $category_id     = $_POST["category_id"] ?? 0;
    $type            = $_POST["type"] ?? "";
    $item_name       = $_POST["item_name"] ?? "";
    $description     = $_POST["description"] ?? "";
    $color           = $_POST["color"] ?? "";
    $location        = $_POST["location"] ?? "";
    $lost_found_date = $_POST["lost_found_date"] ?? "";
    $image_url       = $_POST["image_url"] ?? "";


    if (
        empty($user_id) ||
        empty($category_id) ||
        empty($type) ||
        empty($item_name)
    ) {

        response(
            false,
            "กรุณากรอกข้อมูลให้ครบ"
        );
    }


    if (
        $type != "lost" &&
        $type != "found"
    ) {

        response(
            false,
            "ประเภทข้อมูลไม่ถูกต้อง"
        );
    }


    $stmt = $conn->prepare(
        "INSERT INTO items
        (
            user_id,
            category_id,
            type,
            item_name,
            description,
            color,
            location,
            lost_found_date,
            image_url,
            status,
            created_at,
            updated_at
        )
        VALUES
        (
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            'approved',
            NOW(),
            NOW()
        )"
    );


    $stmt->bind_param(
        "iisssssss",
        $user_id,
        $category_id,
        $type,
        $item_name,
        $description,
        $color,
        $location,
        $lost_found_date,
        $image_url
    );


    if ($stmt->execute()) {

        response(
            true,
            "แจ้งรายการสำเร็จ",
            [
                "item_id" => $stmt->insert_id
            ]
        );

    } else {

        response(
            false,
            "เพิ่มรายการไม่สำเร็จ: " . $stmt->error
        );
    }
}


// =====================================================
// 6b. REPORT FOUND – แจ้งว่าพบของที่มีคนตามหา
// ผู้ใช้กด "ฉันเจอของชิ้นนี้" บนรายการ lost ของคนอื่น
// ส่งแจ้งเตือนไปยังเจ้าของรายการ lost ด้วย
// =====================================================

if ($action == "report_found") {

    $lost_item_id = intval($_POST["lost_item_id"] ?? 0);  // id ของรายการ lost ที่อ้างถึง
    $finder_id    = intval($_POST["finder_id"] ?? 0);     // user_id ของคนที่พบ
    $location     = $_POST["location"] ?? "";
    $description  = $_POST["description"] ?? "";

    if ($lost_item_id <= 0 || $finder_id <= 0) {
        response(false, "ข้อมูลไม่ครบ");
    }

    // ดึงข้อมูลรายการ lost ต้นทาง
    $checkStmt = $conn->prepare(
        "SELECT id, user_id, item_name, type FROM items WHERE id = ? AND status = 'approved'"
    );
    $checkStmt->bind_param("i", $lost_item_id);
    $checkStmt->execute();
    $lostRow = $checkStmt->get_result()->fetch_assoc();

    if (!$lostRow) {
        response(false, "ไม่พบรายการที่อ้างถึง หรือรายการนั้นไม่พร้อมรับรายงาน");
    }

    if ((int)$lostRow["type"] !== 0 && $lostRow["type"] !== "lost") {
        // ยืนยันว่าเป็น lost
        if ($lostRow["type"] !== "lost") {
            response(false, "รายการนี้ไม่ใช่ประเภทของหาย");
        }
    }

    $owner_id = intval($lostRow["user_id"]);

    if ($owner_id === $finder_id) {
        response(false, "คุณเป็นเจ้าของรายการนี้ ไม่สามารถแจ้งว่าพบเองได้");
    }

    // บันทึกรายงานการพบ (ตาราง found_reports)
    // ถ้าตารางยังไม่มีให้สร้างก่อน (หรือใช้ตาราง claims ที่มีอยู่)
    $conn->query("
        CREATE TABLE IF NOT EXISTS found_reports (
            id INT AUTO_INCREMENT PRIMARY KEY,
            lost_item_id INT NOT NULL,
            finder_id INT NOT NULL,
            location VARCHAR(255),
            description TEXT,
            created_at DATETIME DEFAULT NOW()
        )
    ");

    $insReport = $conn->prepare(
        "INSERT INTO found_reports (lost_item_id, finder_id, location, description, created_at)
         VALUES (?, ?, ?, ?, NOW())"
    );
    $insReport->bind_param("iiss", $lost_item_id, $finder_id, $location, $description);

    if (!$insReport->execute()) {
        response(false, "บันทึกรายงานไม่สำเร็จ: " . $insReport->error);
    }

    $report_id = $insReport->insert_id;

    // ส่งแจ้งเตือนไปยังเจ้าของรายการ lost
    if ($owner_id > 0) {
        // ดึงชื่อผู้พบ
        $finderQ = $conn->query(
            "SELECT full_name, username FROM users WHERE id = " . intval($finder_id)
        );
        $finderName = "มีผู้ใช้";
        if ($fRow = $finderQ->fetch_assoc()) {
            $finderName = !empty($fRow["full_name"]) ? $fRow["full_name"] : $fRow["username"];
        }

        $itemName    = $lostRow["item_name"] ?? "สิ่งของของคุณ";
        $notifTitle  = "มีคนพบ: " . $itemName;
        $notifMsg    = $finderName . " แจ้งว่าพบ \"" . $itemName . "\" แล้ว";
        if (!empty($location)) {
            $notifMsg .= " บริเวณ " . $location;
        }
        $notifMsg .= " กรุณาติดต่อกลับหรือตรวจสอบข้อมูล";

        $insNotif = $conn->prepare("
            INSERT INTO notifications (user_id, title, message, item_id, created_at)
            VALUES (?, ?, ?, ?, NOW())
        ");
        if ($insNotif) {
            $insNotif->bind_param("issi", $owner_id, $notifTitle, $notifMsg, $lost_item_id);
            $insNotif->execute();
        }
    }

    response(true, "แจ้งพบของสำเร็จ เจ้าของจะได้รับการแจ้งเตือน", ["report_id" => $report_id]);
}


// =====================================================
// 7. CREATE LOST ITEM
// สำหรับหน้า ReportLostPage ของคุณ
// =====================================================

if ($action == "create_lost_item") {

    $username    = $_POST["username"] ?? "";
    $item_name   = $_POST["item_name"] ?? "";
    $category    = $_POST["category"] ?? "";
    $color       = $_POST["color"] ?? "";
    $location    = $_POST["location"] ?? "";
    $lost_date   = $_POST["lost_date"] ?? "";
    $description = $_POST["description"] ?? "";
    $image_url   = $_POST["image_url"] ?? "";


    // -------------------------------------------------
    // ตรวจสอบข้อมูล
    // -------------------------------------------------

    if (
        empty($username) ||
        empty($item_name) ||
        empty($category) ||
        empty($color) ||
        empty($location) ||
        empty($lost_date) ||
        empty($description)
    ) {

        response(
            false,
            "กรุณากรอกข้อมูลให้ครบ"
        );
    }


    // -------------------------------------------------
    // หา User ID จาก Username
    // -------------------------------------------------

    $stmt = $conn->prepare(
        "SELECT id
         FROM users
         WHERE username = ?"
    );


    $stmt->bind_param(
        "s",
        $username
    );


    $stmt->execute();

    $result = $stmt->get_result();


    if ($result->num_rows == 0) {

        response(
            false,
            "ไม่พบผู้ใช้งาน"
        );
    }


    $user = $result->fetch_assoc();

    $user_id = $user["id"];


    // -------------------------------------------------
    // หา Category ID จากชื่อหมวดหมู่
    // -------------------------------------------------

    $categoryStmt = $conn->prepare(
        "SELECT id
         FROM categories
         WHERE name = ?"
    );


    $categoryStmt->bind_param(
        "s",
        $category
    );


    $categoryStmt->execute();

    $categoryResult = $categoryStmt->get_result();


    if ($categoryResult->num_rows == 0) {

        response(
            false,
            "ไม่พบหมวดหมู่: " . $category
        );
    }


    $categoryData = $categoryResult->fetch_assoc();

    $category_id = $categoryData["id"];


    // -------------------------------------------------
    // เพิ่มรายการลง items
    // -------------------------------------------------

    $stmt = $conn->prepare(
        "INSERT INTO items
        (
            user_id,
            category_id,
            type,
            item_name,
            description,
            color,
            location,
            lost_found_date,
            image_url,
            status,
            created_at,
            updated_at
        )
        VALUES
        (
            ?,
            ?,
            'lost',
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            'pending',
            NOW(),
            NOW()
        )"
    );


    $stmt->bind_param(
        "iissssss",
        $user_id,
        $category_id,
        $item_name,
        $description,
        $color,
        $location,
        $lost_date,
        $image_url
    );


    // -------------------------------------------------
    // บันทึก
    // -------------------------------------------------

    if ($stmt->execute()) {

        response(
            true,
            "แจ้งของหายสำเร็จ รอ Admin ตรวจสอบ",
            [
                "item_id" => $stmt->insert_id,
                "user_id" => $user_id,
                "category_id" => $category_id,
                "type" => "lost",
                "status" => "pending"
            ]
        );

    } else {

        response(
            false,
            "ไม่สามารถบันทึกข้อมูลได้: " . $stmt->error
        );
    }
}


// =====================================================
// 8. MY ITEMS
// รายการที่ User แจ้ง
// =====================================================

if ($action == "my_items") {

    $user_id = $_GET["user_id"] ?? 0;


    $stmt = $conn->prepare(
        "SELECT

            items.*,

            categories.name AS category_name,

            (SELECT claims.id
             FROM claims
             WHERE claims.item_id = items.id
             AND claims.status = 'approved'
             LIMIT 1) AS approved_claim_id

         FROM items

         INNER JOIN categories
            ON items.category_id = categories.id

         WHERE items.user_id = ?

         ORDER BY items.created_at DESC"
    );


    $stmt->bind_param(
        "i",
        $user_id
    );


    $stmt->execute();

    $result = $stmt->get_result();

    $items = [];


    while ($row = $result->fetch_assoc()) {

        $items[] = $row;
    }


    response(
        true,
        "ดึงรายการของฉันสำเร็จ",
        $items
    );
}


// =====================================================
// 9. CLAIM
// ขอรับของ
// =====================================================

if ($action == "claim") {

    $item_id        = $_POST["item_id"] ?? 0;
    $user_id        = $_POST["user_id"] ?? 0;
    $description    = $_POST["description"] ?? "";
    $evidence_image = $_POST["evidence_image"] ?? "";


    if (
        empty($item_id) ||
        empty($user_id)
    ) {

        response(
            false,
            "ข้อมูลไม่ครบ"
        );
    }


    // ตรวจสอบรายการ (ดึงสถานะปัจจุบันมาด้วย เพื่อแจ้งเหตุผลที่ชัดเจน)

    $check = $conn->prepare(
        "SELECT id, status, user_id, item_name, type
         FROM items
         WHERE id = ?"
    );


    $check->bind_param(
        "i",
        $item_id
    );


    $check->execute();

    $itemRow = $check->get_result()->fetch_assoc();


    if (!$itemRow) {

        response(false, "ไม่พบรายการนี้ในระบบ");
    }


    if ((int) $itemRow["user_id"] === (int) $user_id) {

        response(false, "คุณเป็นผู้แจ้งรายการนี้เอง ไม่สามารถยื่นขอรับของตัวเองได้");
    }


    if ($itemRow["status"] !== "approved") {

        $reasons = [
            "pending"  => "รายการนี้ยังไม่ผ่านการตรวจสอบจากแอดมิน กรุณารอสักครู่",
            "rejected" => "รายการนี้ถูกปฏิเสธจากแอดมิน ไม่สามารถขอรับได้",
            "claimed"  => "มีผู้ยื่นขอรับของรายการนี้ไปก่อนแล้ว กรุณารอผลการตรวจสอบ",
            "returned" => "รายการนี้คืนเจ้าของเรียบร้อยแล้ว",
        ];

        response(
            false,
            $reasons[$itemRow["status"]] ?? "รายการนี้ไม่สามารถขอรับของได้"
        );
    }


    // เพิ่ม Claim

    $stmt = $conn->prepare(
        "INSERT INTO claims
        (
            item_id,
            user_id,
            description,
            evidence_image,
            status
        )
        VALUES
        (
            ?,
            ?,
            ?,
            ?,
            'pending'
        )"
    );


    $stmt->bind_param(
        "iiss",
        $item_id,
        $user_id,
        $description,
        $evidence_image
    );


    if ($stmt->execute()) {


        // เปลี่ยนสถานะ Item

        $update = $conn->prepare(
            "UPDATE items
             SET status = 'claimed',
                 updated_at = NOW()
             WHERE id = ?"
        );


        $update->bind_param(
            "i",
            $item_id
        );


        $update->execute();

        // แจ้งเตือนไปยังเจ้าของ/ผู้แจ้งรายการนี้
        $reporter_id = intval($itemRow["user_id"] ?? 0);
        $new_claim_id = $stmt->insert_id;
        if ($reporter_id > 0) {
            $senderQuery = $conn->query("SELECT full_name, username FROM users WHERE id = " . intval($user_id));
            $sName = "มีผู้ใช้";
            if ($sRow = $senderQuery->fetch_assoc()) {
                $sName = !empty($sRow["full_name"]) ? $sRow["full_name"] : $sRow["username"];
            }
            $item_name = $itemRow["item_name"] ?? "สิ่งของของคุณ";
            $notifTitle = "มีผู้ยื่นสิทธิ์ความเป็นเจ้าของ: " . $item_name;
            $notifMsg = $sName . " ได้ยื่นสิทธิ์ขอรับ \"" . $item_name . "\" กรุณาตรวจสอบหรือพูดคุยผ่านการแชท";

            $insNotif = $conn->prepare("
                INSERT INTO notifications (user_id, title, message, claim_id, item_id, created_at)
                VALUES (?, ?, ?, ?, ?, NOW())
            ");
            if ($insNotif) {
                $insNotif->bind_param("issii", $reporter_id, $notifTitle, $notifMsg, $new_claim_id, $item_id);
                $insNotif->execute();
            }
        }

        response(
            true,
            "ส่งคำขอรับของแล้ว",
            [
                "claim_id" => $new_claim_id
            ]
        );

    } else {

        response(
            false,
            "ส่งคำขอรับของไม่สำเร็จ: " . $stmt->error
        );
    }
}


// =====================================================
// 10. GET CLAIMS
// สำหรับ Admin
// =====================================================

if ($action == "claims") {

    requireAdmin($conn);


    $sql = "
        SELECT

            claims.*,

            users.full_name,
            users.email,
            users.phone,

            items.item_name,
            items.type,
            items.image_url

        FROM claims

        INNER JOIN users
            ON claims.user_id = users.id

        INNER JOIN items
            ON claims.item_id = items.id

        ORDER BY claims.created_at DESC
    ";


    $result = $conn->query($sql);

    $claims = [];


    while ($row = $result->fetch_assoc()) {

        $claims[] = $row;
    }


    response(
        true,
        "ดึงคำขอสำเร็จ",
        $claims
    );
}


// =====================================================
// 11. APPROVE CLAIM
// =====================================================

if ($action == "approve_claim") {

    requireAdmin($conn);


    $claim_id  = $_POST["claim_id"] ?? 0;
    $admin_note = $_POST["admin_note"] ?? "";


    if (empty($claim_id)) {

        response(
            false,
            "ไม่พบ Claim ID"
        );
    }


    // หา Item ID

    $stmt = $conn->prepare(
        "SELECT item_id
         FROM claims
         WHERE id = ?"
    );


    $stmt->bind_param(
        "i",
        $claim_id
    );


    $stmt->execute();

    $result = $stmt->get_result();


    if ($result->num_rows == 0) {

        response(
            false,
            "ไม่พบคำขอ"
        );
    }


    $claim = $result->fetch_assoc();

    $item_id = $claim["item_id"];


    // อนุมัติ Claim

    $update = $conn->prepare(
        "UPDATE claims

         SET status = 'approved',
             admin_note = ?

         WHERE id = ?"
    );


    $update->bind_param(
        "si",
        $admin_note,
        $claim_id
    );


    $update->execute();


    // เปลี่ยนสถานะ Item เป็น claimed (เพื่อให้ผู้พบของเป็นคนกดยืนยันคืนของสำเร็จด้วยตนเอง)
    $itemUpdate = $conn->prepare(
        "UPDATE items
         SET status = 'claimed',
             updated_at = NOW()
         WHERE id = ?"
    );

    $itemUpdate->bind_param(
        "i",
        $item_id
    );

    $itemUpdate->execute();

    response(
        true,
        "อนุมัติคำขอเรียบร้อยแล้ว (รอผู้พบของยืนยันการส่งมอบ)"
    );
}


// =====================================================
// 12. REJECT CLAIM
// =====================================================

if ($action == "reject_claim") {

    requireAdmin($conn);


    $claim_id  = $_POST["claim_id"] ?? 0;
    $admin_note = $_POST["admin_note"] ?? "";


    if (empty($claim_id)) {

        response(
            false,
            "ไม่พบ Claim ID"
        );
    }


    $stmt = $conn->prepare(
        "UPDATE claims

         SET status = 'rejected',
             admin_note = ?

         WHERE id = ?"
    );


    $stmt->bind_param(
        "si",
        $admin_note,
        $claim_id
    );


    if ($stmt->execute()) {


        // คืนสถานะรายการกลับเป็น approved เพื่อให้คนอื่นยื่นสิทธิ์ได้อีก

        $revert = $conn->prepare(
            "UPDATE items
             SET status = 'approved', updated_at = NOW()
             WHERE id = (SELECT item_id FROM claims WHERE id = ?)
             AND status = 'claimed'"
        );

        $revert->bind_param("i", $claim_id);
        $revert->execute();

        response(
            true,
            "ปฏิเสธคำขอเรียบร้อยแล้ว"
        );

    } else {

        response(
            false,
            "ไม่สามารถปฏิเสธคำขอได้"
        );
    }
}


// =====================================================
// 13. GET CONVERSATIONS
// Chat ของ User
// User ติดต่อ Admin เท่านั้น
// =====================================================

if ($action == "conversations") {

    $user_id = $_GET["user_id"] ?? 0;


    $stmt = $conn->prepare(
        "SELECT

            conversations.*,

            users.full_name AS admin_name,

            items.item_name

         FROM conversations

         INNER JOIN users
            ON conversations.admin_id = users.id

         LEFT JOIN items
            ON conversations.item_id = items.id

         WHERE conversations.user_id = ?

         ORDER BY conversations.updated_at DESC"
    );


    $stmt->bind_param(
        "i",
        $user_id
    );


    $stmt->execute();

    $result = $stmt->get_result();

    $conversations = [];


    while ($row = $result->fetch_assoc()) {

        $conversations[] = $row;
    }


    response(
        true,
        "ดึงห้อง Chat สำเร็จ",
        $conversations
    );
}


// =====================================================
// 14. CREATE CONVERSATION
// User กับ Admin เท่านั้น
// =====================================================

if ($action == "create_conversation") {

    $user_id  = $_POST["user_id"] ?? 0;
    $admin_id = $_POST["admin_id"] ?? 0;
    $item_id  = $_POST["item_id"] ?? null;


    if (
        empty($user_id) ||
        empty($admin_id)
    ) {

        response(
            false,
            "ข้อมูลไม่ครบ"
        );
    }


    // ตรวจสอบ Admin

    $check = $conn->prepare(
        "SELECT id
         FROM users
         WHERE id = ?
         AND role = 'admin'"
    );


    $check->bind_param(
        "i",
        $admin_id
    );


    $check->execute();

    $result = $check->get_result();


    if ($result->num_rows == 0) {

        response(
            false,
            "ผู้ใช้งานนี้ไม่ใช่ Admin"
        );
    }


    // ตรวจสอบห้องเดิม

    if ($item_id === null || $item_id === "") {

        $existing = $conn->prepare(
            "SELECT id
             FROM conversations
             WHERE user_id = ?
             AND admin_id = ?
             AND item_id IS NULL
             LIMIT 1"
        );


        $existing->bind_param(
            "ii",
            $user_id,
            $admin_id
        );

    } else {

        $item_id = intval($item_id);


        $existing = $conn->prepare(
            "SELECT id
             FROM conversations
             WHERE user_id = ?
             AND admin_id = ?
             AND item_id = ?
             LIMIT 1"
        );


        $existing->bind_param(
            "iii",
            $user_id,
            $admin_id,
            $item_id
        );
    }


    $existing->execute();

    $existingResult = $existing->get_result();


    if ($existingResult->num_rows > 0) {

        $conversation = $existingResult->fetch_assoc();


        response(
            true,
            "พบห้อง Chat เดิม",
            $conversation
        );
    }


    // สร้างห้องใหม่

    if ($item_id === null || $item_id === "") {

        $stmt = $conn->prepare(
            "INSERT INTO conversations
            (
                user_id,
                admin_id,
                item_id
            )
            VALUES
            (
                ?,
                ?,
                NULL
            )"
        );


        $stmt->bind_param(
            "ii",
            $user_id,
            $admin_id
        );

    } else {

        $stmt = $conn->prepare(
            "INSERT INTO conversations
            (
                user_id,
                admin_id,
                item_id
            )
            VALUES
            (
                ?,
                ?,
                ?
            )"
        );


        $stmt->bind_param(
            "iii",
            $user_id,
            $admin_id,
            $item_id
        );
    }


    if ($stmt->execute()) {

        response(
            true,
            "สร้างห้อง Chat สำเร็จ",
            [
                "conversation_id" => $stmt->insert_id
            ]
        );

    } else {

        response(
            false,
            "สร้างห้อง Chat ไม่สำเร็จ: " . $stmt->error
        );
    }
}


// =====================================================
// 15. GET MESSAGES
// =====================================================

if ($action == "messages") {

    $conversation_id =
        $_GET["conversation_id"] ?? 0;


    $stmt = $conn->prepare(
        "SELECT

            messages.*,

            users.full_name,
            users.role

         FROM messages

         INNER JOIN users
            ON messages.sender_id = users.id

         WHERE messages.conversation_id = ?

         ORDER BY messages.created_at ASC"
    );


    $stmt->bind_param(
        "i",
        $conversation_id
    );


    $stmt->execute();

    $result = $stmt->get_result();

    $messages = [];


    while ($row = $result->fetch_assoc()) {

        $messages[] = $row;
    }


    response(
        true,
        "ดึงข้อความสำเร็จ",
        $messages
    );
}


// =====================================================
// 16. SEND MESSAGE
// User <-> Admin เท่านั้น
// =====================================================

if ($action == "send_message") {

    $conversation_id =
        $_POST["conversation_id"] ?? 0;

    $sender_id =
        $_POST["sender_id"] ?? 0;

    $message =
        $_POST["message"] ?? "";

    $image_url =
        $_POST["image_url"] ?? "";


    if (
        empty($conversation_id) ||
        empty($sender_id)
    ) {

        response(
            false,
            "ข้อมูลไม่ครบ"
        );
    }


    if (
        empty($message) &&
        empty($image_url)
    ) {

        response(
            false,
            "กรุณาพิมพ์ข้อความหรือส่งรูป"
        );
    }


    // ตรวจสอบสิทธิ์ผู้ส่ง

    $check = $conn->prepare(
        "SELECT

            conversations.user_id,
            conversations.admin_id,

            users.role

         FROM conversations

         INNER JOIN users
            ON users.id = ?

         WHERE conversations.id = ?

         AND
         (
            conversations.user_id = ?
            OR conversations.admin_id = ?
         )"
    );


    $check->bind_param(
        "iiii",
        $sender_id,
        $conversation_id,
        $sender_id,
        $sender_id
    );


    $check->execute();

    $result = $check->get_result();


    if ($result->num_rows == 0) {

        response(
            false,
            "ไม่มีสิทธิ์ส่งข้อความในห้องนี้"
        );
    }


    // เพิ่มข้อความ

    $stmt = $conn->prepare(
        "INSERT INTO messages
        (
            conversation_id,
            sender_id,
            message,
            image_url
        )
        VALUES
        (
            ?,
            ?,
            ?,
            ?
        )"
    );


    $stmt->bind_param(
        "iiss",
        $conversation_id,
        $sender_id,
        $message,
        $image_url
    );


    if ($stmt->execute()) {


        // อัปเดตเวลา Chat

        $update = $conn->prepare(
            "UPDATE conversations

             SET updated_at = CURRENT_TIMESTAMP

             WHERE id = ?"
        );


        $update->bind_param(
            "i",
            $conversation_id
        );


        $update->execute();


        response(
            true,
            "ส่งข้อความสำเร็จ",
            [
                "message_id" => $stmt->insert_id
            ]
        );

    } else {

        response(
            false,
            "ส่งข้อความไม่สำเร็จ: " . $stmt->error
        );
    }
}


// =====================================================
// 17. NOTIFICATIONS
// =====================================================

if ($action == "notifications") {

    $user_id =
        $_GET["user_id"] ?? 0;


    $stmt = $conn->prepare(
        "SELECT *

         FROM notifications

         WHERE user_id = ?

         ORDER BY created_at DESC"
    );


    $stmt->bind_param(
        "i",
        $user_id
    );


    $stmt->execute();

    $result = $stmt->get_result();

    $notifications = [];


    while ($row = $result->fetch_assoc()) {

        $notifications[] = $row;
    }


    response(
        true,
        "ดึงการแจ้งเตือนสำเร็จ",
        $notifications
    );
}


// =====================================================
// 18. ADMIN ITEMS
// รายการทั้งหมดสำหรับ Admin
// =====================================================

if ($action == "admin_items") {

    requireAdmin($conn);


    $sql = "
        SELECT

            items.*,

            users.full_name,

            categories.name AS category_name

        FROM items

        INNER JOIN users
            ON items.user_id = users.id

        INNER JOIN categories
            ON items.category_id = categories.id

        ORDER BY items.created_at DESC
    ";


    $result = $conn->query($sql);

    $items = [];


    while ($row = $result->fetch_assoc()) {

        $items[] = $row;
    }


    response(
        true,
        "ดึงรายการสำหรับ Admin สำเร็จ",
        $items
    );
}


// =====================================================
// 19. APPROVE ITEM
// Admin อนุมัติรายการ
// =====================================================

if ($action == "approve_item") {

    requireAdmin($conn);


    $item_id =
        $_POST["item_id"] ?? 0;


    if (empty($item_id)) {

        response(
            false,
            "ไม่พบ Item ID"
        );
    }


    $stmt = $conn->prepare(
        "UPDATE items

         SET status = 'approved',
             updated_at = NOW()

         WHERE id = ?"
    );


    $stmt->bind_param(
        "i",
        $item_id
    );


    if ($stmt->execute()) {

        response(
            true,
            "อนุมัติรายการเรียบร้อยแล้ว"
        );

    } else {

        response(
            false,
            "อนุมัติรายการไม่สำเร็จ"
        );
    }
}


// =====================================================
// 20. REJECT ITEM
// Admin ปฏิเสธรายการ
// =====================================================

if ($action == "reject_item") {

    requireAdmin($conn);


    $item_id =
        $_POST["item_id"] ?? 0;


    if (empty($item_id)) {

        response(
            false,
            "ไม่พบ Item ID"
        );
    }


    $stmt = $conn->prepare(
        "UPDATE items

         SET status = 'rejected',
             updated_at = NOW()

         WHERE id = ?"
    );


    $stmt->bind_param(
        "i",
        $item_id
    );


    if ($stmt->execute()) {

        response(
            true,
            "ปฏิเสธรายการเรียบร้อยแล้ว"
        );

    } else {

        response(
            false,
            "ปฏิเสธรายการไม่สำเร็จ"
        );
    }
}


// =====================================================
// 21. UPLOAD IMAGE
// รับไฟล์รูปภาพ (multipart/form-data, field name = "image")
// บันทึกไว้ในโฟลเดอร์ uploads/ แล้วคืนลิงก์กลับไป
// ใช้สำหรับหน้า "แจ้งเรื่องของหาย / พบของ" ฝั่ง Flutter
// =====================================================

if ($action == "upload_image") {

    if (
        !isset($_FILES["image"]) ||
        $_FILES["image"]["error"] !== UPLOAD_ERR_OK
    ) {

        response(
            false,
            "ไม่พบไฟล์รูปภาพ"
        );
    }


    $allowed = ["jpg", "jpeg", "png", "webp"];

    $ext = strtolower(
        pathinfo(
            $_FILES["image"]["name"],
            PATHINFO_EXTENSION
        )
    );


    if (!in_array($ext, $allowed)) {

        response(
            false,
            "รองรับเฉพาะไฟล์ jpg, jpeg, png, webp เท่านั้น"
        );
    }


    $uploadDir = __DIR__ . "/uploads/";

    if (!is_dir($uploadDir)) {

        mkdir($uploadDir, 0755, true);
    }


    $fileName = uniqid("item_", true) . "." . $ext;

    $destination = $uploadDir . $fileName;


    if (
        move_uploaded_file(
            $_FILES["image"]["tmp_name"],
            $destination
        )
    ) {

        $protocol =
            (!empty($_SERVER["HTTPS"])) ? "https://" : "http://";

        $baseUrl =
            $protocol . $_SERVER["HTTP_HOST"] .
            dirname($_SERVER["SCRIPT_NAME"]) .
            "/uploads/" . $fileName;

        response(
            true,
            "อัปโหลดรูปภาพสำเร็จ",
            [
                "url" => $baseUrl
            ]
        );

    } else {

        response(
            false,
            "อัปโหลดรูปภาพไม่สำเร็จ"
        );
    }
}


// =====================================================
// 21.1 VIEW IMAGE (Proxy ส่งรูปภาพพร้อม CORS Header)
// แก้ปัญหา Browser บล็อก CORS เวลาเรียกไฟล์ตรงจากโฟลเดอร์ uploads/
// =====================================================

if ($action == "view_image") {
    $file = basename($_GET["file"] ?? "");
    $filePath = __DIR__ . "/uploads/" . $file;

    if ($file !== "" && file_exists($filePath)) {
        $ext = strtolower(pathinfo($filePath, PATHINFO_EXTENSION));
        $mimeTypes = [
            "jpg" => "image/jpeg",
            "jpeg" => "image/jpeg",
            "png" => "image/png",
            "webp" => "image/webp",
            "gif" => "image/gif"
        ];
        $contentType = $mimeTypes[$ext] ?? "application/octet-stream";

        header("Access-Control-Allow-Origin: *");
        header("Access-Control-Allow-Methods: GET, OPTIONS");
        header("Content-Type: " . $contentType);
        header("Content-Length: " . filesize($filePath));
        header("Cache-Control: public, max-age=86400");
        readfile($filePath);
        exit;
    } else {
        http_response_code(404);
        exit;
    }
}


// =====================================================
// 22. GET STATS
// สรุปสถิติสำหรับการ์ด StatBannerCard หน้า Home
// คืนจำนวนรายการที่ "คืนเจ้าของสำเร็จแล้ว" (status = returned)
// =====================================================

if ($action == "stats") {

    $result = $conn->query(
        "SELECT COUNT(*) AS success_count
         FROM items
         WHERE status = 'returned'"
    );

    $row = $result->fetch_assoc();

    response(
        true,
        "ดึงสถิติสำเร็จ",
        [
            "success_count" => (int) $row["success_count"],
            "lost_count" => (int) $conn->query("SELECT COUNT(*) c FROM items WHERE type='lost' AND status='approved'")->fetch_assoc()["c"],
            "found_count" => (int) $conn->query("SELECT COUNT(*) c FROM items WHERE type='found' AND status='approved'")->fetch_assoc()["c"],
            "member_count" => (int) $conn->query("SELECT COUNT(*) c FROM users")->fetch_assoc()["c"]
        ]
    );
}


// =====================================================
// 23. UPDATE PROFILE
// แก้ไขข้อมูลส่วนตัว / เปลี่ยนรูปโปรไฟล์
// (ต้องมีคอลัมน์ users.avatar_url ก่อน)
// =====================================================

if ($action == "update_profile") {

    $user_id    = intval($_POST["user_id"] ?? 0);
    $full_name  = trim($_POST["full_name"] ?? "");
    $email      = trim($_POST["email"] ?? "");
    $phone      = trim($_POST["phone"] ?? "");
    $avatar_url = trim($_POST["avatar_url"] ?? "");

    if ($user_id <= 0 || $full_name === "") {

        response(false, "กรุณากรอกชื่อ-นามสกุล");
    }

    // avatar_url ว่าง = ไม่เปลี่ยนรูปเดิม

    $stmt = $conn->prepare(
        "UPDATE users
         SET full_name  = ?,
             email      = ?,
             phone      = ?,
             avatar_url = IF(? = '', avatar_url, ?)
         WHERE id = ?"
    );

    $stmt->bind_param(
        "sssssi",
        $full_name,
        $email,
        $phone,
        $avatar_url,
        $avatar_url,
        $user_id
    );

    if (!$stmt->execute()) {

        response(false, "บันทึกข้อมูลไม่สำเร็จ: " . $stmt->error);
    }

    $get = $conn->prepare("SELECT * FROM users WHERE id = ?");
    $get->bind_param("i", $user_id);
    $get->execute();

    $user = $get->get_result()->fetch_assoc();

    if (!$user) {

        response(false, "ไม่พบผู้ใช้งาน");
    }

    unset($user["password"]);

    response(true, "บันทึกข้อมูลสำเร็จ", $user);
}


// =====================================================
// 24. MY CLAIMS
// คำขอรับของที่ User เคยยื่น (ใช้ติดตามสถานะในหน้าโปรไฟล์)
// =====================================================

if ($action == "my_claims") {

    $user_id = intval($_GET["user_id"] ?? 0);

    $stmt = $conn->prepare(
        "SELECT
            claims.*,

            items.item_name,
            items.type,
            items.image_url,
            items.location,
            items.status AS item_status

         FROM claims

         INNER JOIN items
            ON claims.item_id = items.id

         WHERE claims.user_id = ?

         ORDER BY claims.created_at DESC"
    );

    $stmt->bind_param("i", $user_id);
    $stmt->execute();

    $result = $stmt->get_result();

    $claims = [];

    while ($row = $result->fetch_assoc()) {

        $claims[] = $row;
    }

    response(true, "ดึงคำขอของฉันสำเร็จ", $claims);
}


// =====================================================
// 25. GET DEFAULT ADMIN
// คืนแอดมินคนแรกในระบบ ให้ฝั่ง User ใช้เริ่มแชทได้โดยไม่ต้องเลือกเอง
// =====================================================

if ($action == "get_default_admin") {

    $result = $conn->query(
        "SELECT id, full_name, username
         FROM users
         WHERE role = 'admin'
         ORDER BY id ASC
         LIMIT 1"
    );

    if ($result->num_rows == 0) {

        response(false, "ยังไม่มีผู้ดูแลระบบในขณะนี้");
    }

    response(true, "พบผู้ดูแลระบบ", $result->fetch_assoc());
}


// =====================================================
// 26. ADMIN CONVERSATIONS
// ห้องแชททั้งหมดที่ผูกกับ Admin คนนี้ (ใช้ในแอปฝั่ง Admin)
// =====================================================

if ($action == "admin_conversations") {

    requireAdmin($conn);

    $admin_id = intval($_GET["admin_id"] ?? 0);

    $stmt = $conn->prepare(
        "SELECT

            conversations.*,

            users.full_name AS user_full_name,
            users.username AS user_username,
            users.avatar_url AS user_avatar_url,

            items.item_name,

            (SELECT message
             FROM messages
             WHERE messages.conversation_id = conversations.id
             ORDER BY messages.created_at DESC
             LIMIT 1) AS last_message

         FROM conversations

         INNER JOIN users
            ON conversations.user_id = users.id

         LEFT JOIN items
            ON conversations.item_id = items.id

         WHERE conversations.admin_id = ?

         ORDER BY conversations.updated_at DESC"
    );

    $stmt->bind_param("i", $admin_id);
    $stmt->execute();

    $result = $stmt->get_result();

    $conversations = [];

    while ($row = $result->fetch_assoc()) {

        $conversations[] = $row;
    }

    response(true, "ดึงห้อง Chat ของแอดมินสำเร็จ", $conversations);
}


// =====================================================
// 28. OPEN ITEM CHAT
// เปิด (หรือดึงห้องเดิมถ้ามี) ห้องแชทนัดรับของ ระหว่าง "ผู้แจ้ง" (คนโพสต์
// ของหาย/ของพบ) กับ "ผู้ยื่นขอรับ" (เจ้าของจริงที่ยืนยันตัวตนผ่านแอดมินแล้ว)
// อนุญาตเฉพาะ claim ที่แอดมินอนุมัติแล้วเท่านั้น (status = 'approved')
// =====================================================

if ($action == "open_item_chat") {

    $claim_id = intval($_POST["claim_id"] ?? 0);
    $item_id  = intval($_POST["item_id"] ?? 0);
    $user_id  = intval($_POST["user_id"] ?? 0);

    if (($claim_id <= 0 && $item_id <= 0) || $user_id <= 0) {

        response(false, "ข้อมูลไม่ครบ");
    }

    // ดึงข้อมูล claim + item เพื่อหาคู่สนทนาและตรวจสอบสิทธิ์
    if ($claim_id > 0) {
        $stmt = $conn->prepare(
            "SELECT
                claims.id AS claim_id,
                claims.user_id AS claimant_id,
                claims.status AS claim_status,
                items.id AS item_id,
                items.user_id AS reporter_id,
                items.item_name
             FROM claims
             INNER JOIN items
                ON claims.item_id = items.id
             WHERE claims.id = ?"
        );
        $stmt->bind_param("i", $claim_id);
    } else {
        $stmt = $conn->prepare(
            "SELECT
                claims.id AS claim_id,
                claims.user_id AS claimant_id,
                claims.status AS claim_status,
                items.id AS item_id,
                items.user_id AS reporter_id,
                items.item_name
             FROM claims
             INNER JOIN items
                ON claims.item_id = items.id
             WHERE claims.item_id = ?
             ORDER BY claims.id DESC
             LIMIT 1"
        );
        $stmt->bind_param("i", $item_id);
    }

    $stmt->execute();

    $row = $stmt->get_result()->fetch_assoc();

    if (!$row) {

        response(false, "ไม่พบคำขอรับของนี้");
    }

    // อนุญาตให้แชทได้ทั้งตอน pending/claimed (มีคนยื่นสิทธิ์), approved, returned
    if ($row["claim_status"] === "rejected") {

        response(false, "คำขอนี้ถูกปฏิเสธแล้ว");
    }

    $reporter_id = (int) $row["reporter_id"];
    $claimant_id = (int) $row["claimant_id"];
    $claim_id    = (int) $row["claim_id"];

    if ($user_id !== $reporter_id && $user_id !== $claimant_id) {

        response(false, "คุณไม่มีสิทธิ์เข้าห้องแชทนี้");
    }

    // มีห้องอยู่แล้วหรือยัง (ผูก 1 ห้องต่อ 1 claim)

    $existing = $conn->prepare(
        "SELECT id FROM item_chats WHERE claim_id = ? LIMIT 1"
    );
    $existing->bind_param("i", $claim_id);
    $existing->execute();

    $existingRow = $existing->get_result()->fetch_assoc();

    if ($existingRow) {

        $item_chat_id = (int) $existingRow["id"];

    } else {

        $insert = $conn->prepare(
            "INSERT INTO item_chats
                (item_id, claim_id, reporter_id, claimant_id)
             VALUES (?, ?, ?, ?)"
        );

        $insert->bind_param(
            "iiii",
            $row["item_id"],
            $claim_id,
            $reporter_id,
            $claimant_id
        );

        if (!$insert->execute()) {

            response(false, "เปิดห้องแชทไม่สำเร็จ: " . $insert->error);
        }

        $item_chat_id = $insert->insert_id;
    }

    // ส่งแจ้งเตือนไปยังฝ่ายตรงข้าม (โดยเฉพาะเจ้าของของ) เมื่อมีคนเริ่มเปิดแชท
    $target_notif_user = ($user_id === $reporter_id) ? $claimant_id : $reporter_id;
    if ($target_notif_user > 0) {
        $senderQ = $conn->query("SELECT full_name, username FROM users WHERE id = " . intval($user_id));
        $sName = "มีผู้ใช้";
        if ($sRow = $senderQ->fetch_assoc()) {
            $sName = !empty($sRow["full_name"]) ? $sRow["full_name"] : $sRow["username"];
        }
        $itemName = $row["item_name"] ?? "สิ่งของของคุณ";
        $chatNotifTitle = "มีคนแชทมาหาคุณ: " . $itemName;
        $chatNotifMsg = $sName . " ได้เปิดการสนทนาเกี่ยวกับ \"" . $itemName . "\" แตะเพื่อพูดคุย";

        $insChatNotif = $conn->prepare("
            INSERT INTO notifications (user_id, title, message, claim_id, item_id, created_at)
            VALUES (?, ?, ?, ?, ?, NOW())
        ");
        if ($insChatNotif) {
            $insChatNotif->bind_param("issii", $target_notif_user, $chatNotifTitle, $chatNotifMsg, $claim_id, $row["item_id"]);
            $insChatNotif->execute();
        }
    }

    $peer_id = ($user_id === $reporter_id) ? $claimant_id : $reporter_id;

    $peer = $conn->prepare(
        "SELECT full_name, username, avatar_url FROM users WHERE id = ?"
    );
    $peer->bind_param("i", $peer_id);
    $peer->execute();

    $peerInfo = $peer->get_result()->fetch_assoc();

    response(true, "เปิดห้องแชทสำเร็จ", [
        "item_chat_id" => $item_chat_id,
        "item_name"    => $row["item_name"],
        "peer_id"      => $peer_id,
        "peer_name"    => $peerInfo["full_name"] ?? $peerInfo["username"] ?? "ผู้ใช้งาน",
        "peer_avatar"  => $peerInfo["avatar_url"] ?? "",
    ]);
}


// =====================================================
// 29. ITEM CHATS (LIST)
// รายการห้องแชทนัดรับของทั้งหมดของ user คนนี้ (ทั้งฝั่งผู้แจ้งและผู้ยื่นขอรับ)
// =====================================================

if ($action == "item_chats") {

    $user_id = intval($_GET["user_id"] ?? 0);

    $stmt = $conn->prepare(
        "SELECT

            item_chats.*,

            items.item_name,
            items.image_url,

            CASE
                WHEN item_chats.reporter_id = ? THEN item_chats.claimant_id
                ELSE item_chats.reporter_id
            END AS peer_id,

            CASE
                WHEN item_chats.reporter_id = ? THEN claimant.full_name
                ELSE reporter.full_name
            END AS peer_name,

            CASE
                WHEN item_chats.reporter_id = ? THEN claimant.avatar_url
                ELSE reporter.avatar_url
            END AS peer_avatar,

            (SELECT message
             FROM item_chat_messages
             WHERE item_chat_messages.item_chat_id = item_chats.id
             ORDER BY item_chat_messages.created_at DESC
             LIMIT 1) AS last_message

         FROM item_chats

         INNER JOIN items
            ON item_chats.item_id = items.id

         INNER JOIN users AS reporter
            ON item_chats.reporter_id = reporter.id

         INNER JOIN users AS claimant
            ON item_chats.claimant_id = claimant.id

         WHERE item_chats.reporter_id = ?
         OR item_chats.claimant_id = ?

         ORDER BY item_chats.updated_at DESC"
    );

    $stmt->bind_param("iiiii", $user_id, $user_id, $user_id, $user_id, $user_id);
    $stmt->execute();

    $result = $stmt->get_result();
    $chats = [];

    while ($row = $result->fetch_assoc()) {

        $chats[] = $row;
    }

    response(true, "ดึงห้องแชทนัดรับของสำเร็จ", $chats);
}


// =====================================================
// 30. ITEM CHAT MESSAGES
// =====================================================

if ($action == "item_chat_messages") {

    $item_chat_id = intval($_GET["item_chat_id"] ?? 0);

    $stmt = $conn->prepare(
        "SELECT

            item_chat_messages.*,

            users.full_name,
            users.role

         FROM item_chat_messages

         INNER JOIN users
            ON item_chat_messages.sender_id = users.id

         WHERE item_chat_messages.item_chat_id = ?

         ORDER BY item_chat_messages.created_at ASC"
    );

    $stmt->bind_param("i", $item_chat_id);
    $stmt->execute();

    $result = $stmt->get_result();
    $messages = [];

    while ($row = $result->fetch_assoc()) {

        $messages[] = $row;
    }

    response(true, "ดึงข้อความสำเร็จ", $messages);
}


// =====================================================
// 31. SEND ITEM CHAT MESSAGE
// อนุญาตเฉพาะ reporter หรือ claimant ของห้องนั้นเท่านั้น
// =====================================================

if ($action == "send_item_chat_message") {

    $item_chat_id = intval($_POST["item_chat_id"] ?? 0);
    $sender_id    = intval($_POST["sender_id"] ?? 0);
    $message      = trim($_POST["message"] ?? "");
    $image_url    = trim($_POST["image_url"] ?? "");

    if ($item_chat_id <= 0 || $sender_id <= 0) {

        response(false, "ข้อมูลไม่ครบ");
    }

    if ($message === "" && $image_url === "") {

        response(false, "กรุณาพิมพ์ข้อความหรือส่งรูป");
    }

    $check = $conn->prepare(
        "SELECT reporter_id, claimant_id
         FROM item_chats
         WHERE id = ?"
    );
    $check->bind_param("i", $item_chat_id);
    $check->execute();

    $room = $check->get_result()->fetch_assoc();

    if (!$room) {

        response(false, "ไม่พบห้องแชทนี้");
    }

    if ($sender_id !== (int) $room["reporter_id"] &&
        $sender_id !== (int) $room["claimant_id"]) {

        response(false, "คุณไม่มีสิทธิ์ส่งข้อความในห้องนี้");
    }

    $stmt = $conn->prepare(
        "INSERT INTO item_chat_messages
            (item_chat_id, sender_id, message, image_url)
         VALUES (?, ?, ?, ?)"
    );

    $stmt->bind_param(
        "iiss",
        $item_chat_id,
        $sender_id,
        $message,
        $image_url
    );

    if ($stmt->execute()) {

        $touch = $conn->prepare(
            "UPDATE item_chats SET updated_at = NOW() WHERE id = ?"
        );
        $touch->bind_param("i", $item_chat_id);
        $touch->execute();

        // แจ้งเตือนไปยังผู้รับว่ามีข้อความใหม่
        $recipient_id = ($sender_id === (int)$room["reporter_id"]) ? (int)$room["claimant_id"] : (int)$room["reporter_id"];
        if ($recipient_id > 0) {
            $senderQ = $conn->query("SELECT full_name, username FROM users WHERE id = " . intval($sender_id));
            $sName = "มีผู้ใช้";
            if ($sRow = $senderQ->fetch_assoc()) {
                $sName = !empty($sRow["full_name"]) ? $sRow["full_name"] : $sRow["username"];
            }

            // ดึงชื่อ item และ claim_id
            $itemQ = $conn->query("SELECT item_id, claim_id FROM item_chats WHERE id = " . intval($item_chat_id));
            $cRow = $itemQ ? $itemQ->fetch_assoc() : null;
            $cItemId = intval($cRow["item_id"] ?? 0);
            $cClaimId = intval($cRow["claim_id"] ?? 0);

            $iQ = $conn->query("SELECT item_name FROM items WHERE id = " . $cItemId);
            $iRow = $iQ ? $iQ->fetch_assoc() : null;
            $itemName = $iRow["item_name"] ?? "สิ่งของ";

            $notifTitle = "มีคนแชทมาหาคุณ: " . $itemName;
            $msgSnippet = !empty($message) ? $message : "[ส่งรูปภาพ]";
            if (mb_strlen($msgSnippet) > 50) {
                $msgSnippet = mb_substr($msgSnippet, 0, 47) . "...";
            }
            $notifMsg = $sName . ": " . $msgSnippet;

            $insMsgNotif = $conn->prepare("
                INSERT INTO notifications (user_id, title, message, claim_id, item_id, created_at)
                VALUES (?, ?, ?, ?, ?, NOW())
            ");
            if ($insMsgNotif) {
                $insMsgNotif->bind_param("issii", $recipient_id, $notifTitle, $notifMsg, $cClaimId, $cItemId);
                $insMsgNotif->execute();
            }
        }

        response(true, "ส่งข้อความสำเร็จ", [
            "message_id" => $stmt->insert_id,
        ]);

    } else {

        response(false, "ส่งข้อความไม่สำเร็จ: " . $stmt->error);
    }
}


// =====================================================
// 32. UPDATE ITEM
// ผู้แจ้งแก้ไขรายการของตัวเอง — แก้ไม่ได้ถ้ามีคนยื่นขอรับแล้ว (claimed/returned)
// แก้เสร็จรีเซ็ตสถานะกลับเป็น 'pending' เพื่อให้แอดมินตรวจสอบใหม่เสมอ
// (กันกรณีแก้ข้อมูลหลอกหลังผ่านการอนุมัติไปแล้ว)
// =====================================================

if ($action == "update_item") {

    $item_id       = intval($_POST["item_id"] ?? 0);
    $user_id       = intval($_POST["user_id"] ?? 0);
    $category_id   = intval($_POST["category_id"] ?? 0);
    $item_name     = trim($_POST["item_name"] ?? "");
    $color         = trim($_POST["color"] ?? "");
    $location      = trim($_POST["location"] ?? "");
    $lost_found_date = trim($_POST["lost_found_date"] ?? "");
    $description   = trim($_POST["description"] ?? "");
    $image_url     = trim($_POST["image_url"] ?? "");

    if ($item_id <= 0 || $user_id <= 0 || $item_name === "" || $category_id <= 0) {

        response(false, "ข้อมูลไม่ครบ");
    }

    $check = $conn->prepare(
        "SELECT user_id, status FROM items WHERE id = ?"
    );
    $check->bind_param("i", $item_id);
    $check->execute();

    $item = $check->get_result()->fetch_assoc();

    if (!$item) {

        response(false, "ไม่พบรายการนี้");
    }

    if ((int) $item["user_id"] !== $user_id) {

        response(false, "คุณไม่มีสิทธิ์แก้ไขรายการนี้");
    }

    if (in_array($item["status"], ["claimed", "returned"])) {

        $reasons = [
            "claimed"  => "มีผู้ยื่นขอรับของรายการนี้แล้ว ไม่สามารถแก้ไขได้",
            "returned" => "รายการนี้คืนเจ้าของเรียบร้อยแล้ว ไม่สามารถแก้ไขได้",
        ];

        response(false, $reasons[$item["status"]]);
    }

    $stmt = $conn->prepare(
        "UPDATE items
         SET category_id = ?,
             item_name = ?,
             color = ?,
             location = ?,
             lost_found_date = ?,
             description = ?,
             image_url = ?,
             status = 'pending',
             updated_at = NOW()
         WHERE id = ?"
    );

    $stmt->bind_param(
        "issssssi",
        $category_id,
        $item_name,
        $color,
        $location,
        $lost_found_date,
        $description,
        $image_url,
        $item_id
    );

    if ($stmt->execute()) {

        response(true, "แก้ไขรายการสำเร็จ รอแอดมินตรวจสอบอีกครั้ง");

    } else {

        response(false, "แก้ไขรายการไม่สำเร็จ: " . $stmt->error);
    }
}


// =====================================================
// 33. DELETE ITEM
// ผู้แจ้งลบรายการของตัวเอง — ลบไม่ได้ถ้ามีคนยื่นขอรับแล้ว (claimed/returned)
// =====================================================

if ($action == "delete_item") {

    $item_id = intval($_POST["item_id"] ?? 0);
    $user_id = intval($_POST["user_id"] ?? 0);

    if ($item_id <= 0 || $user_id <= 0) {

        response(false, "ข้อมูลไม่ครบ");
    }

    $check = $conn->prepare(
        "SELECT user_id, status FROM items WHERE id = ?"
    );
    $check->bind_param("i", $item_id);
    $check->execute();

    $item = $check->get_result()->fetch_assoc();

    if (!$item) {

        response(false, "ไม่พบรายการนี้");
    }

    if ((int) $item["user_id"] !== $user_id) {

        response(false, "คุณไม่มีสิทธิ์ลบรายการนี้");
    }

    if (in_array($item["status"], ["claimed", "returned"])) {

        $reasons = [
            "claimed"  => "มีผู้ยื่นขอรับของรายการนี้แล้ว ไม่สามารถลบได้",
            "returned" => "รายการนี้คืนเจ้าของเรียบร้อยแล้ว ไม่สามารถลบได้",
        ];

        response(false, $reasons[$item["status"]]);
    }

    $stmt = $conn->prepare("DELETE FROM items WHERE id = ?");
    $stmt->bind_param("i", $item_id);

    if ($stmt->execute()) {

        response(true, "ลบรายการสำเร็จ");

    } else {

        response(false, "ลบรายการไม่สำเร็จ: " . $stmt->error);
    }
}


// =====================================================
// CHAT: User <-> User (นัดรับของระหว่างผู้แจ้งและผู้ยื่นขอรับ)
// ไม่ต้องรอแอดมินอนุมัติก่อน สามารถแชทคุยกันได้ทันที
// =====================================================

// 34. เปิด (หรือดึงห้องเดิม) แชทนัดรับของ / คุยกับผู้แจ้ง
if ($action == "open_item_chat") {
    $claim_id = intval($_POST["claim_id"] ?? 0);
    $item_id  = intval($_POST["item_id"] ?? 0);
    $user_id  = intval($_POST["user_id"] ?? 0);

    if ($user_id <= 0 || ($claim_id <= 0 && $item_id <= 0)) {
        response(false, "ข้อมูลไม่ครบถ้วน (ต้องระบุ user_id และ claim_id หรือ item_id)");
    }

    $reporter_id = 0;
    $claimant_id = 0;
    $item_name   = "สิ่งของ";

    if ($claim_id > 0) {
        $stmt = $conn->prepare("
            SELECT c.id AS claim_id, c.item_id, c.user_id AS claimant_id, i.user_id AS reporter_id, i.item_name
            FROM claims c
            JOIN items i ON c.item_id = i.id
            WHERE c.id = ?
        ");
        $stmt->bind_param("i", $claim_id);
        $stmt->execute();
        $claim = $stmt->get_result()->fetch_assoc();

        if (!$claim) {
            response(false, "ไม่พบข้อมูลคำขอนี้");
        }
        $reporter_id = intval($claim["reporter_id"]);
        $claimant_id = intval($claim["claimant_id"]);
        $item_id     = intval($claim["item_id"]);
        $item_name   = $claim["item_name"];
    } else {
        // กรณีเปิดตรงจากหน้า Home ด้วย item_id
        $stmt = $conn->prepare("SELECT user_id, item_name FROM items WHERE id = ?");
        $stmt->bind_param("i", $item_id);
        $stmt->execute();
        $itemRow = $stmt->get_result()->fetch_assoc();
        if (!$itemRow) {
            response(false, "ไม่พบรายการสิ่งของนี้");
        }
        $reporter_id = intval($itemRow["user_id"]);
        $claimant_id = $user_id; // คนที่กดแชทคือ claimant / ผู้ติดต่อ
        $item_name   = $itemRow["item_name"];

        if ($reporter_id === $user_id) {
            response(false, "คุณเป็นผู้แจ้งรายการนี้อยู่แล้ว");
        }
    }

    if ($user_id !== $reporter_id && $user_id !== $claimant_id) {
        response(false, "คุณไม่มีสิทธิ์เข้าถึงห้องแชทนี้");
    }

    // ตรวจสอบว่ามีห้องเดิมแล้วหรือไม่
    $stmtCheck = $conn->prepare("
        SELECT id FROM item_chats 
        WHERE (item_id = ? AND reporter_id = ? AND claimant_id = ?)
           OR (claim_id > 0 AND claim_id = ?)
        LIMIT 1
    ");
    $stmtCheck->bind_param("iiii", $item_id, $reporter_id, $claimant_id, $claim_id);
    $stmtCheck->execute();
    $chatRes = $stmtCheck->get_result()->fetch_assoc();

    if ($chatRes) {
        $chat_id = intval($chatRes["id"]);
    } else {
        $stmtIns = $conn->prepare("
            INSERT INTO item_chats (claim_id, item_id, reporter_id, claimant_id, created_at, updated_at)
            VALUES (?, ?, ?, ?, NOW(), NOW())
        ");
        $stmtIns->bind_param("iiii", $claim_id, $item_id, $reporter_id, $claimant_id);
        if (!$stmtIns->execute()) {
            response(false, "สร้างห้องแชทไม่สำเร็จ: " . $stmtIns->error);
        }
        $chat_id = $stmtIns->insert_id;

        // หากเป็นการสร้างห้องใหม่ และผู้ที่กดเปิดคือคนอื่น (claimant/ผู้พบ) ให้แจ้งเตือนไปยังผู้แจ้งรายการ
        if ($user_id !== $reporter_id && $reporter_id > 0) {
            $senderQuery = $conn->query("SELECT full_name, username FROM users WHERE id = " . intval($user_id));
            $sName = "มีผู้ใช้";
            if ($sRow = $senderQuery->fetch_assoc()) {
                $sName = !empty($sRow["full_name"]) ? $sRow["full_name"] : $sRow["username"];
            }
            $notifTitle = "มีผู้ติดต่อเกี่ยวกับ: " . $item_name;
            $notifMsg = $sName . " ได้เปิดการสนทนาเกี่ยวกับรายการ \"" . $item_name . "\" ของคุณ";

            $insNotif = $conn->prepare("
                INSERT INTO notifications (user_id, title, message, created_at)
                VALUES (?, ?, ?, NOW())
            ");
            if ($insNotif) {
                $insNotif->bind_param("iss", $reporter_id, $notifTitle, $notifMsg);
                $insNotif->execute();
            }
        }
    }

    // ดึงชื่อของคู่สนทนา (peer_name)
    $peer_id = ($user_id === $reporter_id) ? $claimant_id : $reporter_id;
    $stmtUser = $conn->prepare("SELECT full_name, username FROM users WHERE id = ?");
    $stmtUser->bind_param("i", $peer_id);
    $stmtUser->execute();
    $peer = $stmtUser->get_result()->fetch_assoc();
    $peer_name = (!empty($peer["full_name"])) ? $peer["full_name"] : ($peer["username"] ?? "ผู้ใช้งาน");

    response(true, "เปิดห้องแชทสำเร็จ", [
        "item_chat_id" => $chat_id,
        "item_name"    => $item_name,
        "peer_name"    => $peer_name,
        "peer_id"      => $peer_id,
    ]);
}

// 35. รายการห้องแชทนัดรับของทั้งหมดของ User
if ($action == "item_chats") {
    $user_id = intval($_GET["user_id"] ?? 0);
    if ($user_id <= 0) {
        response(false, "กรุณาระบุ user_id");
    }

    $stmt = $conn->prepare("
        SELECT 
            ic.id,
            ic.claim_id,
            ic.item_id,
            ic.updated_at,
            i.item_name,
            CASE 
                WHEN ic.reporter_id = ? THEN COALESCE(u2.full_name, u2.username)
                ELSE COALESCE(u1.full_name, u1.username)
            END AS peer_name,
            (SELECT message FROM item_chat_messages WHERE item_chat_id = ic.id ORDER BY id DESC LIMIT 1) AS last_message
        FROM item_chats ic
        LEFT JOIN items i ON ic.item_id = i.id
        LEFT JOIN users u1 ON ic.reporter_id = u1.id
        LEFT JOIN users u2 ON ic.claimant_id = u2.id
        WHERE ic.reporter_id = ? OR ic.claimant_id = ?
        ORDER BY ic.updated_at DESC
    ");
    $stmt->bind_param("iii", $user_id, $user_id, $user_id);
    $stmt->execute();
    $result = $stmt->get_result();

    $chats = [];
    while ($row = $result->fetch_assoc()) {
        $chats[] = $row;
    }

    response(true, "ดึงรายการแชทสำเร็จ", $chats);
}

// 36. ดึงข้อความทั้งหมดในห้องแชทนัดรับของ
if ($action == "item_chat_messages") {
    $chat_id = intval($_GET["item_chat_id"] ?? 0);
    if ($chat_id <= 0) {
        response(false, "กรุณาระบุ item_chat_id");
    }

    $stmt = $conn->prepare("
        SELECT id, item_chat_id, sender_id, message, image_url, created_at
        FROM item_chat_messages
        WHERE item_chat_id = ?
        ORDER BY id ASC
    ");
    $stmt->bind_param("i", $chat_id);
    $stmt->execute();
    $result = $stmt->get_result();

    $messages = [];
    while ($row = $result->fetch_assoc()) {
        $messages[] = $row;
    }

    response(true, "ดึงข้อความสำเร็จ", $messages);
}

// 37. ส่งข้อความในห้องแชทนัดรับของ (พร้อมบันทึกการแจ้งเตือนไปยังคู่สนทนา)
if ($action == "send_item_chat_message") {
    $chat_id   = intval($_POST["item_chat_id"] ?? 0);
    $sender_id = intval($_POST["sender_id"] ?? 0);
    $message   = trim($_POST["message"] ?? "");
    $image_url = trim($_POST["image_url"] ?? "");

    if ($chat_id <= 0 || $sender_id <= 0) {
        response(false, "ข้อมูลไม่ครบถ้วน");
    }

    if (empty($message) && empty($image_url)) {
        response(false, "ข้อความว่างเปล่า");
    }

    $stmt = $conn->prepare("
        INSERT INTO item_chat_messages (item_chat_id, sender_id, message, image_url, created_at)
        VALUES (?, ?, ?, ?, NOW())
    ");
    $stmt->bind_param("iiss", $chat_id, $sender_id, $message, $image_url);

    if ($stmt->execute()) {
        $msg_id = $stmt->insert_id;
        $conn->query("UPDATE item_chats SET updated_at = NOW() WHERE id = " . $chat_id);

        // ดึงข้อมูลห้องเพื่อแจ้งเตือนฝ่ายตรงข้าม
        $qChat = $conn->query("SELECT reporter_id, claimant_id, item_id FROM item_chats WHERE id = $chat_id");
        if ($cRow = $qChat->fetch_assoc()) {
            $receiver_id = ($sender_id === intval($cRow['reporter_id'])) ? intval($cRow['claimant_id']) : intval($cRow['reporter_id']);
            $senderQuery = $conn->query("SELECT full_name, username FROM users WHERE id = $sender_id");
            $sName = "มีคน";
            if ($sRow = $senderQuery->fetch_assoc()) {
                $sName = !empty($sRow['full_name']) ? $sRow['full_name'] : $sRow['username'];
            }
            $notifTitle = "ข้อความใหม่จาก " . $sName;
            $notifMsg = !empty($message) ? $message : "[ส่งรูปภาพ]";

            // บันทึกการแจ้งเตือน
            $insNotif = $conn->prepare("
                INSERT INTO notifications (user_id, title, message, created_at)
                VALUES (?, ?, ?, NOW())
            ");
            if ($insNotif) {
                $insNotif->bind_param("iss", $receiver_id, $notifTitle, $notifMsg);
                $insNotif->execute();
            }
        }

        response(true, "ส่งข้อความสำเร็จ", ["id" => $msg_id]);
    } else {
        response(false, "ส่งข้อความไม่สำเร็จ: " . $stmt->error);
    }
}

// =====================================================
// 38. NOTIFICATIONS: ระบบการแจ้งเตือน
// =====================================================

// ดึงการแจ้งเตือนของ User
if ($action == "notifications") {
    $user_id = intval($_GET["user_id"] ?? 0);
    if ($user_id <= 0) {
        response(false, "กรุณาระบุ user_id");
    }

    $stmt = $conn->prepare("
        SELECT id, user_id, title, message, is_read, claim_id, item_id, created_at
        FROM notifications
        WHERE user_id = ?
        ORDER BY created_at DESC
        LIMIT 50
    ");
    $stmt->bind_param("i", $user_id);
    $stmt->execute();
    $result = $stmt->get_result();

    $notifications = [];
    while ($row = $result->fetch_assoc()) {
        $notifications[] = $row;
    }

    response(true, "ดึงการแจ้งเตือนสำเร็จ", $notifications);
}

// อ่านการแจ้งเตือนทั้งหมด
// อ่านการแจ้งเตือนทั้งหมด
if ($action == "mark_notifications_read") {
    $user_id = intval($_POST["user_id"] ?? 0);
    if ($user_id <= 0) {
        response(false, "กรุณาระบุ user_id");
    }

    $stmt = $conn->prepare("UPDATE notifications SET is_read = 1 WHERE user_id = ?");
    $stmt->bind_param("i", $user_id);
    $stmt->execute();

    response(true, "อ่านการแจ้งเตือนแล้ว");
}

// =====================================================
// 39. CONFIRM RETURN: ผู้พบยืนยันคืนของสำเร็จด้วยตัวเอง
// =====================================================

if ($action == "confirm_return") {
    $item_id = intval($_POST["item_id"] ?? 0);
    $user_id = intval($_POST["user_id"] ?? 0);

    if ($item_id <= 0 || $user_id <= 0) {
        response(false, "กรุณาระบุ item_id และ user_id");
    }

    // ดึงข้อมูล item โดยไม่ผูก user_id ไว้ใน query (ตรวจสิทธิ์แยก)
    $stmtCheck = $conn->prepare("SELECT id, status, user_id, type FROM items WHERE id = ? LIMIT 1");
    $stmtCheck->bind_param("i", $item_id);
    $stmtCheck->execute();
    $itemRow = $stmtCheck->get_result()->fetch_assoc();

    if (!$itemRow) {
        response(false, "ไม่พบรายการนี้ในระบบ");
    }

    if ($itemRow["status"] !== "claimed") {
        response(false, "รายการนี้ไม่อยู่ในสถานะที่สามารถยืนยันได้ (ต้องเป็น claimed)");
    }

    // ตรวจสิทธิ์: เป็นเจ้าของ item หรือเป็น claimant ที่ได้รับอนุมัติ
    $isOwner = ($itemRow["user_id"] == $user_id);
    $isClaimant = false;

    if (!$isOwner) {
        $stmtClaim = $conn->prepare(
            "SELECT id FROM claims WHERE item_id = ? AND user_id = ? AND status = 'approved' LIMIT 1"
        );
        $stmtClaim->bind_param("ii", $item_id, $user_id);
        $stmtClaim->execute();
        $isClaimant = ($stmtClaim->get_result()->num_rows > 0);
    }

    if (!$isOwner && !$isClaimant) {
        response(false, "ไม่มีสิทธิ์ยืนยันรายการนี้");
    }

    $stmtUpd = $conn->prepare("UPDATE items SET status = 'returned', updated_at = NOW() WHERE id = ?");
    $stmtUpd->bind_param("i", $item_id);
    if (!$stmtUpd->execute()) {
        response(false, "ยืนยันไม่สำเร็จ: " . $stmtUpd->error);
    }

    response(true, "ยืนยันคืนของสำเร็จเรียบร้อยแล้ว");
}

// =====================================================
// 40. CONFIRM RECEIVED: เจ้าของของหายยืนยันว่าได้รับของคืนแล้ว
// =====================================================

if ($action == "confirm_received") {
    $item_id = intval($_POST["item_id"] ?? 0);
    $user_id = intval($_POST["user_id"] ?? 0);

    if ($item_id <= 0 || $user_id <= 0) {
        response(false, "กรุณาระบุ item_id และ user_id");
    }

    // ดึงข้อมูล item
    $stmtItem = $conn->prepare(
        "SELECT id, status, type, user_id FROM items WHERE id = ? LIMIT 1"
    );
    $stmtItem->bind_param("i", $item_id);
    $stmtItem->execute();
    $itemRow = $stmtItem->get_result()->fetch_assoc();

    if (!$itemRow) {
        response(false, "ไม่พบรายการ");
    }

    if (!in_array($itemRow["status"], ["claimed", "approved"])) {
        response(false, "รายการนี้ไม่อยู่ในสถานะที่สามารถยืนยันได้");
    }

    $isOwner     = ($itemRow["type"] === "lost" && $itemRow["user_id"] == $user_id);
    $isClaimant  = false;

    if (!$isOwner) {
        // ตรวจว่า user เป็นผู้ยื่น claim ที่ได้รับอนุมัติสำหรับ item นี้
        $stmtClaim = $conn->prepare(
            "SELECT id FROM claims WHERE item_id = ? AND user_id = ? AND status = 'approved' LIMIT 1"
        );
        $stmtClaim->bind_param("ii", $item_id, $user_id);
        $stmtClaim->execute();
        $isClaimant = ($stmtClaim->get_result()->num_rows > 0);
    }

    if (!$isOwner && !$isClaimant) {
        response(false, "ไม่มีสิทธิ์ยืนยันรายการนี้");
    }

    $stmtUpd = $conn->prepare(
        "UPDATE items SET status = 'returned', updated_at = NOW() WHERE id = ?"
    );
    $stmtUpd->bind_param("i", $item_id);
    if (!$stmtUpd->execute()) {
        response(false, "ยืนยันไม่สำเร็จ: " . $stmtUpd->error);
    }

    response(true, "ยืนยันรับของคืนสำเร็จเรียบร้อยแล้ว");
}

// =====================================================
// 41. ถ้าไม่พบ action
// =====================================================

response(
    false,
    "ไม่พบ API action ที่ร้องขอ"
);

?>