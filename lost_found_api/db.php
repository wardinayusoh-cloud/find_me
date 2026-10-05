<?php

$host = "172.18.111.42";
$dbname = "6620310157_";
$username = "6620310157";
$password = "6620310157";

$conn = new mysqli(
    $host,
    $username,
    $password,
    $dbname
);

if ($conn->connect_error) {
    die("Database connection failed: " . $conn->connect_error);
}

$conn->set_charset("utf8mb4");

?>