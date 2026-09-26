-- =====================================================================
--  Molaplan – tee käyttäjästä ylläpitäjä
--  1) Käyttäjän on ensin rekisteröidyttävä sovelluksessa.
--  2) Vaihda alla oleva sähköpostiosoite ja aja Supabasen SQL Editorissa.
--  Ylläpitäjä näkee Profiili-sivulla "Ylläpito"-kortin ja avunpyyntöjen
--  tarkistusjonon (sekä pyytäjien puhelinnumerot ja sähköpostit).
-- =====================================================================

update public.profiles
set is_admin = true
where id = (select id from auth.users where lower(email) = lower('SINUN.OSOITE@esim.fi'));

-- Tarkista lopputulos: kaikki ylläpitäjät
select p.id, u.email, p.display_name, p.is_admin
from public.profiles p
join auth.users u on u.id = p.id
where p.is_admin;

-- Ylläpitäjyyden poisto:
-- update public.profiles set is_admin = false
-- where id = (select id from auth.users where lower(email) = lower('SINUN.OSOITE@esim.fi'));
