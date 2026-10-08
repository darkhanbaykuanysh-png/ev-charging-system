-- EV Charging System database schema (SQL Server)
-- Лабораториялық жұмыс 6: Class Diagram негізіндегі 8 кесте

CREATE TABLE Users (
    user_id INT IDENTITY(1,1) PRIMARY KEY,
    full_name NVARCHAR(100) NOT NULL,
    email NVARCHAR(150) NOT NULL UNIQUE,
    phone NVARCHAR(30) NULL,
    password_hash NVARCHAR(255) NOT NULL,
    role NVARCHAR(20) NOT NULL DEFAULT 'client',
    created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT CK_Users_role CHECK (role IN ('client', 'operator', 'admin'))
);

CREATE TABLE Vehicles (
    vehicle_id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT NOT NULL,
    vehicle_type NVARCHAR(20) NOT NULL,
    brand NVARCHAR(50) NULL,
    model NVARCHAR(50) NULL,
    battery_capacity_kwh DECIMAL(6,2) NULL,
    connector_type NVARCHAR(30) NULL,
    license_plate NVARCHAR(20) NULL,
    created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT FK_Vehicles_Users FOREIGN KEY (user_id) REFERENCES Users(user_id),
    CONSTRAINT CK_Vehicles_type CHECK (vehicle_type IN ('ev', 'escooter', 'emoped', 'ebike'))
);

CREATE TABLE Stations (
    station_id INT IDENTITY(1,1) PRIMARY KEY,
    operator_id INT NOT NULL,
    name NVARCHAR(120) NOT NULL,
    address NVARCHAR(200) NOT NULL,
    city NVARCHAR(80) NOT NULL,
    latitude DECIMAL(9,6) NULL,
    longitude DECIMAL(9,6) NULL,
    status NVARCHAR(20) NOT NULL DEFAULT 'active',
    created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT FK_Stations_Users FOREIGN KEY (operator_id) REFERENCES Users(user_id),
    CONSTRAINT CK_Stations_status CHECK (status IN ('active', 'inactive', 'maintenance'))
);

CREATE TABLE ChargePoints (
    charge_point_id INT IDENTITY(1,1) PRIMARY KEY,
    station_id INT NOT NULL,
    connector_type NVARCHAR(30) NOT NULL,
    power_kw DECIMAL(6,2) NOT NULL,
    status NVARCHAR(20) NOT NULL DEFAULT 'available',
    CONSTRAINT FK_ChargePoints_Stations FOREIGN KEY (station_id) REFERENCES Stations(station_id),
    CONSTRAINT CK_ChargePoints_status CHECK (status IN ('available', 'occupied', 'reserved', 'out_of_service'))
);

CREATE TABLE Tariffs (
    tariff_id INT IDENTITY(1,1) PRIMARY KEY,
    station_id INT NOT NULL,
    vehicle_type NVARCHAR(20) NOT NULL,
    price_per_kwh DECIMAL(10,2) NOT NULL,
    price_per_minute DECIMAL(10,2) NOT NULL DEFAULT 0,
    currency CHAR(3) NOT NULL DEFAULT 'KZT',
    valid_from DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    valid_to DATETIME2 NULL,
    CONSTRAINT FK_Tariffs_Stations FOREIGN KEY (station_id) REFERENCES Stations(station_id),
    CONSTRAINT CK_Tariffs_type CHECK (vehicle_type IN ('ev', 'escooter', 'emoped', 'ebike'))
);

CREATE TABLE Bookings (
    booking_id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT NOT NULL,
    charge_point_id INT NOT NULL,
    start_time DATETIME2 NOT NULL,
    end_time DATETIME2 NOT NULL,
    status NVARCHAR(20) NOT NULL DEFAULT 'active',
    created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT FK_Bookings_Users FOREIGN KEY (user_id) REFERENCES Users(user_id),
    CONSTRAINT FK_Bookings_ChargePoints FOREIGN KEY (charge_point_id) REFERENCES ChargePoints(charge_point_id),
    CONSTRAINT CK_Bookings_status CHECK (status IN ('active', 'cancelled', 'completed', 'expired')),
    CONSTRAINT CK_Bookings_time CHECK (end_time > start_time)
);

CREATE TABLE ChargingSessions (
    session_id INT IDENTITY(1,1) PRIMARY KEY,
    booking_id INT NULL,
    user_id INT NOT NULL,
    charge_point_id INT NOT NULL,
    started_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    ended_at DATETIME2 NULL,
    energy_kwh DECIMAL(8,2) NULL,
    amount DECIMAL(12,2) NULL,
    status NVARCHAR(20) NOT NULL DEFAULT 'in_progress',
    CONSTRAINT FK_ChargingSessions_Bookings FOREIGN KEY (booking_id) REFERENCES Bookings(booking_id),
    CONSTRAINT FK_ChargingSessions_Users FOREIGN KEY (user_id) REFERENCES Users(user_id),
    CONSTRAINT FK_ChargingSessions_ChargePoints FOREIGN KEY (charge_point_id) REFERENCES ChargePoints(charge_point_id),
    CONSTRAINT CK_ChargingSessions_status CHECK (status IN ('in_progress', 'completed', 'failed'))
);

CREATE TABLE Payments (
    payment_id INT IDENTITY(1,1) PRIMARY KEY,
    session_id INT NOT NULL,
    user_id INT NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    method NVARCHAR(20) NOT NULL DEFAULT 'card',
    status NVARCHAR(20) NOT NULL DEFAULT 'pending',
    transaction_ref NVARCHAR(100) NULL,
    paid_at DATETIME2 NULL,
    created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT FK_Payments_ChargingSessions FOREIGN KEY (session_id) REFERENCES ChargingSessions(session_id),
    CONSTRAINT FK_Payments_Users FOREIGN KEY (user_id) REFERENCES Users(user_id),
    CONSTRAINT CK_Payments_method CHECK (method IN ('card', 'wallet')),
    CONSTRAINT CK_Payments_status CHECK (status IN ('pending', 'paid', 'failed', 'refunded'))
);

CREATE INDEX IX_Stations_city ON Stations(city);
CREATE INDEX IX_ChargePoints_station_status ON ChargePoints(station_id, status);
CREATE INDEX IX_Bookings_user_time ON Bookings(user_id, start_time);
CREATE INDEX IX_ChargingSessions_user ON ChargingSessions(user_id);
CREATE INDEX IX_Payments_session ON Payments(session_id);


CREATE TABLE New (
    1_bagan INT NOT NULL,
    2_BAGAN NVARCHAR(),
    3_bagan INT
    );
