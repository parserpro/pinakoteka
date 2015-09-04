# первый патч - создает таблицу для учета патчей

# prepare
unless ( table('patches') ) {
    schema()->alter(qq{CREATE TABLE patches (id INT AUTO_INCREMENT, data VARCHAR(40), PRIMARY KEY (id))});
    say "table created";
}
else {
    say "table exists";
}
