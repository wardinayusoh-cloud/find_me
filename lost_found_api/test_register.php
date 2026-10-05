<?php

$url = "https://std.mcs.psu.ac.th/6620310157/html/lost_found_api/api.php?action=register";

$data = [
    "username" => "testuser",
    "password" => "123456",
    "full_name" => "ผู้ใช้ทดสอบ",
    "email" => "test@gmail.com",
    "phone" => "0800000000"
];

$options = [
    "http" => [
        "header"  => "Content-Type: application/x-www-form-urlencoded\r\n",
        "method"  => "POST",
        "content" => http_build_query($data)
    ]
];

$context = stream_context_create($options);

$result = file_get_contents($url, false, $context);

echo "<pre>";
echo $result;
echo "</pre>";

?>