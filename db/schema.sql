USE master;
GO
IF DB_ID(N'EVChargingDB') IS NOT NULL
BEGIN
    ALTER DATABASE EVChargingDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE EVChargingDB;
END
GO
CREATE DATABASE EVChargingDB;
GO
USE EVChargingDB;
GO

-- 1. users (класс User)
CREATE TABLE users (
    user_id        INT IDENTITY(1,1) PRIMARY KEY,
    full_name      NVARCHAR(100) NOT NULL,
    phone          VARCHAR(20)   NOT NULL UNIQUE,
    email          VARCHAR(100)  NOT NULL UNIQUE,
    password_hash  VARCHAR(255)  NOT NULL,
    user_role      VARCHAR(20)   NOT NULL DEFAULT 'client',
    CONSTRAINT ck_users_role CHECK (user_role IN ('client','operator','admin')),
    CONSTRAINT ck_users_email CHECK (email LIKE '%_@_%._%')
);
GO

-- 2. vehicles (класс Vehicle)
CREATE TABLE vehicles (
    vehicle_id        INT IDENTITY(1,1) PRIMARY KEY,
    user_id           INT           NOT NULL,
    vehicle_type      VARCHAR(20)   NOT NULL,
    plug_type         VARCHAR(30)   NOT NULL,
    battery_capacity  DECIMAL(6,2)  NOT NULL,
    CONSTRAINT fk_vehicles_users FOREIGN KEY (user_id) REFERENCES users(user_id),
    CONSTRAINT ck_vehicles_type CHECK (vehicle_type IN ('car','moped','scooter','bicycle')),
    CONSTRAINT ck_vehicles_battery CHECK (battery_capacity > 0)
);
GO

-- 3. stations (класс Station)
CREATE TABLE stations (
    station_id   INT IDENTITY(1,1) PRIMARY KEY,
    operator_id  INT            NOT NULL,
    name         NVARCHAR(100)  NOT NULL,
    address      NVARCHAR(200)  NOT NULL,
    latitude     DECIMAL(9,6)   NOT NULL,
    longitude    DECIMAL(9,6)   NOT NULL,
    work_hours   VARCHAR(50)    NOT NULL DEFAULT '00:00-24:00',
    status       VARCHAR(20)    NOT NULL DEFAULT 'active',
    CONSTRAINT fk_stations_operator FOREIGN KEY (operator_id) REFERENCES users(user_id),
    CONSTRAINT ck_stations_lat CHECK (latitude  BETWEEN -90  AND 90),
    CONSTRAINT ck_stations_lon CHECK (longitude BETWEEN -180 AND 180),
    CONSTRAINT ck_stations_status CHECK (status IN ('active','inactive','maintenance'))
);
GO

-- 4. charging_slots (класс ChargingSlot, Station-мен композиция)
CREATE TABLE charging_slots (
    slot_id       INT IDENTITY(1,1) PRIMARY KEY,
    station_id    INT           NOT NULL,
    plug_type     VARCHAR(30)   NOT NULL,
    power_output  DECIMAL(6,2)  NOT NULL,
    status        VARCHAR(20)   NOT NULL DEFAULT 'free',
    CONSTRAINT fk_slots_station FOREIGN KEY (station_id)
        REFERENCES stations(station_id) ON DELETE CASCADE,
    CONSTRAINT ck_slots_power CHECK (power_output > 0),
    CONSTRAINT ck_slots_status CHECK (status IN ('free','booked','busy','out_of_order'))
);
GO

-- 5. tariffs (класс Tariff)
CREATE TABLE tariffs (
    tariff_id         INT IDENTITY(1,1) PRIMARY KEY,
    vehicle_type      VARCHAR(20)   NOT NULL,
    price_per_kwh     DECIMAL(8,2)  NOT NULL,
    price_per_minute  DECIMAL(8,2)  NOT NULL DEFAULT 0,
    valid_from        DATE          NOT NULL,
    CONSTRAINT ck_tariffs_type CHECK (vehicle_type IN ('car','moped','scooter','bicycle')),
    CONSTRAINT ck_tariffs_kwh CHECK (price_per_kwh >= 0),
    CONSTRAINT ck_tariffs_min CHECK (price_per_minute >= 0)
);
GO

-- 6. bookings (класс Booking)
CREATE TABLE bookings (
    booking_id  INT IDENTITY(1,1) PRIMARY KEY,
    user_id     INT          NOT NULL,
    vehicle_id  INT          NOT NULL,
    slot_id     INT          NOT NULL,
    start_time  DATETIME2    NOT NULL,
    end_time    DATETIME2    NOT NULL,
    status      VARCHAR(20)  NOT NULL DEFAULT 'pending',
    CONSTRAINT fk_bookings_user    FOREIGN KEY (user_id)    REFERENCES users(user_id),
    CONSTRAINT fk_bookings_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles(vehicle_id),
    CONSTRAINT fk_bookings_slot    FOREIGN KEY (slot_id)    REFERENCES charging_slots(slot_id),
    CONSTRAINT ck_bookings_time   CHECK (end_time > start_time),
    CONSTRAINT ck_bookings_status CHECK (status IN ('pending','confirmed','cancelled','completed'))
);
GO

-- 7. charging_sessions (класс ChargingSession;)
CREATE TABLE charging_sessions (
    session_id        INT IDENTITY(1,1) PRIMARY KEY,
    booking_id        INT            NOT NULL UNIQUE,
    tariff_id         INT            NOT NULL,
    start_time        DATETIME2      NOT NULL,
    end_time          DATETIME2      NULL,
    energy_delivered  DECIMAL(8,3)   NOT NULL DEFAULT 0,
    total_cost        DECIMAL(10,2)  NULL,
    status            VARCHAR(20)    NOT NULL DEFAULT 'active',
    CONSTRAINT fk_sessions_booking FOREIGN KEY (booking_id) REFERENCES bookings(booking_id),
    CONSTRAINT fk_sessions_tariff  FOREIGN KEY (tariff_id)  REFERENCES tariffs(tariff_id),
    CONSTRAINT ck_sessions_time   CHECK (end_time IS NULL OR end_time > start_time),
    CONSTRAINT ck_sessions_energy CHECK (energy_delivered >= 0),
    CONSTRAINT ck_sessions_cost   CHECK (total_cost IS NULL OR total_cost >= 0),
    CONSTRAINT ck_sessions_status CHECK (status IN ('active','completed','interrupted'))
);
GO

-- 8. payments (класс Payment;)
CREATE TABLE payments (
    payment_id      INT IDENTITY(1,1) PRIMARY KEY,
    session_id      INT            NULL,
    amount          DECIMAL(10,2)  NOT NULL,
    payment_method  VARCHAR(20)    NOT NULL,
    status          VARCHAR(20)    NOT NULL DEFAULT 'pending',
    paid_at         DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT fk_payments_session FOREIGN KEY (session_id) REFERENCES charging_sessions(session_id),
    CONSTRAINT ck_payments_amount CHECK (amount > 0),
    CONSTRAINT ck_payments_method CHECK (payment_method IN ('card','apple_pay','google_pay')),
    CONSTRAINT ck_payments_status CHECK (status IN ('pending','success','failed','refunded'))
);
GO

-- users
INSERT INTO users (full_name, phone, email, password_hash, user_role) VALUES
(N'Азамат Серіков',  '+77011112233', 'azamat@mail.kz', 'hash_a1b2c3d4', 'client'),
(N'Алия Нұрлан',     '+77022223344', 'aliya@mail.kz',  'hash_e5f6g7h8', 'client'),
(N'Дана Оспанова',   '+77033334455', 'dana@mail.kz',   'hash_i9j0k1l2', 'client'),
(N'Ерлан Төлеген',   '+77044445566', 'erlan@ev.kz',    'hash_m3n4o5p6', 'operator'),
(N'Админ Жүйе',      '+77055556677', 'admin@ev.kz',    'hash_q7r8s9t0', 'admin');
GO

-- vehicles
INSERT INTO vehicles (user_id, vehicle_type, plug_type, battery_capacity) VALUES
(1, 'car',     'CCS2',   75.00),
(1, 'scooter', 'Schuko',  0.50),
(2, 'moped',   'Schuko',  2.50),
(3, 'bicycle', 'Schuko',  0.40);
GO

-- stations 
INSERT INTO stations (operator_id, name, address, latitude, longitude, work_hours, status) VALUES
(4, N'EV Station Достық',  N'Алматы, Достық даңғылы 112',  43.238949, 76.945465, '00:00-24:00', 'active'),
(4, N'EV Station Mega',    N'Алматы, Розыбакиев көшесі 247', 43.202710, 76.893570, '08:00-23:00', 'active'),
(4, N'EV Point Әл-Фараби', N'Алматы, Әл-Фараби даңғылы 77', 43.218300, 76.929100, '09:00-21:00', 'active');
GO

-- charging_slots
INSERT INTO charging_slots (station_id, plug_type, power_output, status) VALUES
(1, 'CCS2',   60.00,  'free'),
(1, 'Type 2', 22.00,  'free'),
(2, 'CCS2',   150.00, 'free'),
(2, 'Schuko', 3.00,   'free'),
(3, 'Schuko', 0.50,   'free'),
(3, 'Schuko', 0.50,   'free');
GO

-- tariffs
INSERT INTO tariffs (vehicle_type, price_per_kwh, price_per_minute, valid_from) VALUES
('car',     120.00, 5.00, '2026-01-01'),
('moped',    90.00, 2.00, '2026-01-01'),
('scooter',  80.00, 1.00, '2026-01-01'),
('bicycle',  80.00, 1.00, '2026-01-01');
GO

-- bookings
INSERT INTO bookings (user_id, vehicle_id, slot_id, start_time, end_time, status) VALUES
(1, 1, 1, '2026-10-06T10:00:00', '2026-10-06T11:00:00', 'completed'),
(2, 3, 4, '2026-10-06T12:00:00', '2026-10-06T12:45:00', 'completed'),
(3, 4, 5, '2026-10-08T15:00:00', '2026-10-08T15:30:00', 'confirmed'),
(1, 2, 6, '2026-10-08T16:00:00', '2026-10-08T16:30:00', 'pending'),
(1, 1, 3, '2026-10-08T18:00:00', '2026-10-08T19:00:00', 'cancelled');
GO

-- charging_sessions
INSERT INTO charging_sessions (booking_id, tariff_id, start_time, end_time, energy_delivered, total_cost, status) VALUES
(1, 1, '2026-10-06T10:05:00', '2026-10-06T10:55:00', 38.500, 4620.00, 'completed'),
(2, 2, '2026-10-06T12:05:00', '2026-10-06T12:40:00',  1.800,  162.00, 'completed');
GO

-- payments 
INSERT INTO payments (session_id, amount, payment_method, status) VALUES
(1,    4620.00, 'card',       'success'),
(2,     162.00, 'apple_pay',  'success'),
(NULL,  500.00, 'google_pay', 'pending');
GO


SELECT * FROM users;
SELECT * FROM vehicles;
SELECT * FROM stations;
SELECT * FROM charging_slots;
SELECT * FROM tariffs;
SELECT * FROM bookings;
SELECT * FROM charging_sessions;
SELECT * FROM payments;



IF NOT EXISTS (SELECT 1 FROM users WHERE email = 'saule@ev.kz')
    INSERT INTO users (full_name, phone, email, password_hash, user_role)
    VALUES (N'Сәуле Бекова', '+77066667788', 'saule@ev.kz', 'hash_u1v2w3x4', 'operator');
GO


IF NOT EXISTS (SELECT 1 FROM stations WHERE name = N'EV Station Арбат')
BEGIN
    INSERT INTO stations (operator_id, name, address, latitude, longitude, work_hours, status) VALUES
    ((SELECT user_id FROM users WHERE email = 'erlan@ev.kz'), N'EV Station Арбат',  N'Алматы, Жібек Жолы даңғылы 50',        43.256500, 76.945700, '00:00-24:00', 'active'),
    ((SELECT user_id FROM users WHERE email = 'erlan@ev.kz'), N'EV Point Алатау',   N'Алматы, Сейфуллин даңғылы 617',        43.264400, 76.939100, '08:00-22:00', 'active'),
    ((SELECT user_id FROM users WHERE email = 'erlan@ev.kz'), N'EV Station Жетісу', N'Алматы, Жетісу-2 шағынауданы 55',      43.237100, 76.880600, '00:00-24:00', 'active'),
    ((SELECT user_id FROM users WHERE email = 'saule@ev.kz'), N'EV Station Әуежай', N'Алматы, Майлин көшесі 2 (әуежай)',      43.352100, 77.040500, '00:00-24:00', 'active'),
    ((SELECT user_id FROM users WHERE email = 'saule@ev.kz'), N'EV Point Медеу',    N'Алматы, Медеу жолы 1',                 43.157300, 77.058600, '09:00-20:00', 'maintenance'),
    ((SELECT user_id FROM users WHERE email = 'saule@ev.kz'), N'EV Point Тастақ',   N'Алматы, Тастақ шағынауданы 12',        43.220800, 76.903300, '09:00-21:00', 'inactive');
 
    INSERT INTO charging_slots (station_id, plug_type, power_output, status) VALUES
    -- Арбат
    ((SELECT station_id FROM stations WHERE name = N'EV Station Арбат'),  'CCS2',    120.00, 'free'),
    ((SELECT station_id FROM stations WHERE name = N'EV Station Арбат'),  'Type 2',   22.00, 'free'),
    ((SELECT station_id FROM stations WHERE name = N'EV Station Арбат'),  'Schuko',    3.00, 'busy'),
    -- Алатау
    ((SELECT station_id FROM stations WHERE name = N'EV Point Алатау'),   'Type 2',   11.00, 'free'),
    ((SELECT station_id FROM stations WHERE name = N'EV Point Алатау'),   'Schuko',    3.00, 'free'),
    ((SELECT station_id FROM stations WHERE name = N'EV Point Алатау'),   'Schuko',    0.50, 'free'),
    -- Жетісу
    ((SELECT station_id FROM stations WHERE name = N'EV Station Жетісу'), 'CCS2',    150.00, 'free'),
    ((SELECT station_id FROM stations WHERE name = N'EV Station Жетісу'), 'CHAdeMO',  50.00, 'busy'),
    ((SELECT station_id FROM stations WHERE name = N'EV Station Жетісу'), 'Type 2',   22.00, 'free'),
    ((SELECT station_id FROM stations WHERE name = N'EV Station Жетісу'), 'Schuko',    3.00, 'free'),
    -- Әуежай
    ((SELECT station_id FROM stations WHERE name = N'EV Station Әуежай'), 'CCS2',    180.00, 'free'),
    ((SELECT station_id FROM stations WHERE name = N'EV Station Әуежай'), 'CCS2',    180.00, 'booked'),
    ((SELECT station_id FROM stations WHERE name = N'EV Station Әуежай'), 'Type 2',   22.00, 'free'),
    -- Медеу
    ((SELECT station_id FROM stations WHERE name = N'EV Point Медеу'),    'Type 2',    7.40, 'out_of_order'),
    ((SELECT station_id FROM stations WHERE name = N'EV Point Медеу'),    'Schuko',    3.00, 'out_of_order'),
    -- Тастақ
    ((SELECT station_id FROM stations WHERE name = N'EV Point Тастақ'),   'Schuko',    0.50, 'free'),
    ((SELECT station_id FROM stations WHERE name = N'EV Point Тастақ'),   'Schuko',    0.50, 'free');
END
GO


SELECT s.station_id, s.name, s.status, COUNT(c.slot_id) AS slot_count
FROM stations AS s
LEFT JOIN charging_slots AS c ON c.station_id = s.station_id
GROUP BY s.station_id, s.name, s.status
ORDER BY s.station_id;
GO

USE EVChargingDB;
GO
 
IF NOT EXISTS (SELECT 1 FROM bookings WHERE slot_id = 1 AND start_time = '2026-10-01T09:00:00')
BEGIN
    -- 1. Жаңа брондаулар (11)
    INSERT INTO bookings (user_id, vehicle_id, slot_id, start_time, end_time, status) VALUES
        (1, 1, 1, '2026-10-01T09:00:00', '2026-10-01T10:00:00', 'completed'),
        (1, 1, 3, '2026-10-02T14:00:00', '2026-10-02T15:00:00', 'completed'),
        (2, 3, 4, '2026-10-02T11:00:00', '2026-10-02T12:00:00', 'completed'),
        (3, 4, 5, '2026-10-03T17:00:00', '2026-10-03T17:30:00', 'completed'),
        (1, 2, 6, '2026-10-03T19:00:00', '2026-10-03T19:40:00', 'completed'),
        (1, 1, 1, '2026-10-04T08:00:00', '2026-10-04T09:00:00', 'completed'),
        (2, 3, 4, '2026-10-05T13:00:00', '2026-10-05T14:00:00', 'completed'),
        (3, 4, 6, '2026-10-05T16:00:00', '2026-10-05T16:30:00', 'completed'),
        (1, 1, 3, '2026-10-06T20:00:00', '2026-10-06T21:00:00', 'completed'),
        (2, 3, 4, '2026-10-07T10:00:00', '2026-10-07T10:45:00', 'completed'),
        (3, 4, 5, '2026-10-15T12:00:00', '2026-10-15T13:00:00', 'confirmed');
 
    -- 2. Зарядтау сессиялары (11): әр брондауға бір сессия
    --    total_cost = energy_delivered * price_per_kwh (қолданылатын тариф бойынша)
    INSERT INTO charging_sessions (booking_id, tariff_id, start_time, end_time, energy_delivered, total_cost, status)
    SELECT b.booking_id,
           (SELECT TOP 1 t.tariff_id FROM tariffs AS t WHERE t.vehicle_type = v.vtype ORDER BY t.valid_from DESC),
           CAST(v.s_start AS DATETIME2),
           CAST(v.s_end   AS DATETIME2),
           v.energy,
           v.cost,
           v.s_status
    FROM (VALUES
        (1, '2026-10-01T09:00:00', 'car', '2026-10-01T09:03:00', '2026-10-01T09:52:00', 42.000, 5040.00, 'completed'),
        (3, '2026-10-02T14:00:00', 'car', '2026-10-02T14:02:00', '2026-10-02T14:41:00', 55.500, 6660.00, 'completed'),
        (4, '2026-10-02T11:00:00', 'moped', '2026-10-02T11:05:00', '2026-10-02T11:50:00', 2.100, 189.00, 'completed'),
        (5, '2026-10-03T17:00:00', 'bicycle', '2026-10-03T17:02:00', '2026-10-03T17:27:00', 0.200, 16.00, 'completed'),
        (6, '2026-10-03T19:00:00', 'scooter', '2026-10-03T19:03:00', '2026-10-03T19:36:00', 0.250, 20.00, 'completed'),
        (1, '2026-10-04T08:00:00', 'car', '2026-10-04T08:05:00', '2026-10-04T08:20:00', 8.200, 984.00, 'interrupted'),
        (4, '2026-10-05T13:00:00', 'moped', '2026-10-05T13:01:00', '2026-10-05T13:48:00', 2.300, 207.00, 'completed'),
        (6, '2026-10-05T16:00:00', 'bicycle', '2026-10-05T16:02:00', '2026-10-05T16:28:00', 0.210, 16.80, 'completed'),
        (3, '2026-10-06T20:00:00', 'car', '2026-10-06T20:04:00', '2026-10-06T20:55:00', 48.200, 5784.00, 'completed'),
        (4, '2026-10-07T10:00:00', 'moped', '2026-10-07T10:03:00', '2026-10-07T10:44:00', 1.950, 175.50, 'completed'),
        (5, '2026-10-15T12:00:00', 'bicycle', '2026-10-15T12:02:00', NULL, 0.050, NULL, 'active')
    ) AS v (slot_id, b_start, vtype, s_start, s_end, energy, cost, s_status)
    JOIN bookings AS b ON b.slot_id = v.slot_id AND b.start_time = CAST(v.b_start AS DATETIME2);
 
    -- 3. Төлемдер (12): бір сессияға бірнеше төлем болуы мүмкін (сәтсіз әрекет + қайталау)
    INSERT INTO payments (session_id, amount, payment_method, status, paid_at)
    SELECT cs.session_id, v.amount, v.method, v.p_status, CAST(v.paid_at AS DATETIME2)
    FROM (VALUES
        (1, '2026-10-01T09:00:00', 5040.00, 'card', 'success', '2026-10-01T09:54:00'),
        (3, '2026-10-02T14:00:00', 6660.00, 'apple_pay', 'success', '2026-10-02T14:43:00'),
        (4, '2026-10-02T11:00:00', 189.00, 'google_pay', 'success', '2026-10-02T11:52:00'),
        (5, '2026-10-03T17:00:00', 16.00, 'card', 'success', '2026-10-03T17:29:00'),
        (6, '2026-10-03T19:00:00', 20.00, 'apple_pay', 'success', '2026-10-03T19:38:00'),
        (1, '2026-10-04T08:00:00', 984.00, 'card', 'refunded', '2026-10-04T08:30:00'),
        (4, '2026-10-05T13:00:00', 207.00, 'card', 'success', '2026-10-05T13:50:00'),
        (6, '2026-10-05T16:00:00', 16.80, 'google_pay', 'failed', '2026-10-05T16:29:00'),
        (6, '2026-10-05T16:00:00', 16.80, 'card', 'success', '2026-10-05T16:33:00'),
        (3, '2026-10-06T20:00:00', 5784.00, 'card', 'success', '2026-10-06T20:57:00'),
        (4, '2026-10-07T10:00:00', 175.50, 'apple_pay', 'success', '2026-10-07T10:46:00'),
        (5, '2026-10-15T12:00:00', 40.00, 'card', 'pending', '2026-10-15T12:02:00')
    ) AS v (slot_id, b_start, amount, method, p_status, paid_at)
    JOIN bookings AS b ON b.slot_id = v.slot_id AND b.start_time = CAST(v.b_start AS DATETIME2)
    JOIN charging_sessions AS cs ON cs.booking_id = b.booking_id;
END
GO





SELECT * FROM users;
SELECT * FROM vehicles;
SELECT * FROM stations;
SELECT * FROM charging_slots;
SELECT * FROM tariffs;
SELECT * FROM bookings;
SELECT * FROM charging_sessions;
SELECT * FROM payments;


SELECT
    b.booking_id,
    u.full_name,
    v.vehicle_type,
    s.name AS station_name,
    c.plug_type,
    b.start_time,
    b.status
FROM bookings AS b
JOIN users AS u ON u.user_id = b.user_id
JOIN vehicles AS v ON v.vehicle_id = b.vehicle_id
JOIN charging_slots AS c ON c.slot_id = b.slot_id
JOIN stations AS s ON s.station_id = c.station_id
ORDER BY b.start_time;





SELECT
    p.payment_id,
    u.full_name,
    s.name AS station_name,
    cs.energy_delivered,
    p.amount,
    p.payment_method
FROM payments AS p
JOIN charging_sessions AS cs ON cs.session_id = p.session_id
JOIN bookings AS b ON b.booking_id = cs.booking_id
JOIN users AS u ON u.user_id = b.user_id
JOIN charging_slots AS c ON c.slot_id = b.slot_id
JOIN stations AS s ON s.station_id = c.station_id
WHERE p.status = 'success'
ORDER BY p.amount DESC;




SELECT
    u.full_name,
    cs.session_id,
    cs.energy_delivered,
    cs.total_cost
FROM charging_sessions AS cs
JOIN bookings AS b ON b.booking_id = cs.booking_id
JOIN users AS u ON u.user_id = b.user_id
WHERE cs.total_cost = (
    SELECT MAX(total_cost)
    FROM charging_sessions
);




SELECT
    c.slot_id,
    s.name AS station_name,
    c.power_output,
    CASE
        WHEN c.power_output >= 100 THEN N'Өте жылдам'
        WHEN c.power_output >= 22 THEN N'Жылдам'
        WHEN c.power_output >= 3 THEN N'Қалыпты'
        ELSE N'Баяу'
    END AS power_category
FROM charging_slots AS c
JOIN stations AS s ON s.station_id = c.station_id
ORDER BY c.power_output DESC;