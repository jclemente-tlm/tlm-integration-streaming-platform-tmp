-- create new user
CREATE USER LIM_W1_HL IDENTIFIED BY lim123;

-- grant priviledges
GRANT CONNECT, RESOURCE, DBA TO LIM_W1_HL;
