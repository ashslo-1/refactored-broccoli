/*
 * FLauncher
 * Copyright (C) 2021  Étienne Fesser
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations.dart';
import 'package:flauncher/database.dart';
import 'package:flauncher/models/category.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v1.dart' as v1;
import 'generated_migrations/schema_v2.dart' as v2;
import 'generated_migrations/schema_v3.dart' as v3;
import 'generated_migrations/schema_v4.dart' as v4;

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test("upgrade from v1 to v8", () async {
    final schema = await verifier.schemaAt(1);

    final oldDb = v1.DatabaseAtV1(schema.newConnection().executor);
    await oldDb.customStatement(
      "INSERT INTO apps (package_name, name, class_name, version) VALUES ('me.efesser.flauncher', 'FLauncher', '.MainActivity', '0.0.1');",
    );
    await oldDb.customStatement(
      "INSERT INTO categories (id, name, \"order\") VALUES (1, 'Applications', 0);",
    );
    await oldDb.customStatement(
      "INSERT INTO apps_categories (category_id, app_package_name, \"order\") VALUES (1, 'me.efesser.flauncher', 0);",
    );
    await oldDb.close();

    final db = FLauncherDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 8);

    final app = await db.select(db.apps).getSingle();
    final category = await db.select(db.categories).getSingle();
    final appsCategory = await db.select(db.appsCategories).getSingle();
    expect(app.packageName, "me.efesser.flauncher");
    expect(app.name, "FLauncher");
    expect(app.version, "0.0.1");
    expect(app.hidden, false);
    expect(category.id, 1);
    expect(category.name, "Applications");
    expect(category.order, 0);
    expect(category.sort, CategorySort.manual);
    expect(category.type, CategoryType.grid);
    expect(category.columnsCount, 6);
    expect(category.rowHeight, 110);
    expect(appsCategory.appPackageName, "me.efesser.flauncher");
    expect(appsCategory.categoryId, 1);
    expect(appsCategory.order, 0);
    await db.close();
  });

  test("upgrade from v2 to v8", () async {
    final schema = await verifier.schemaAt(2);

    final oldDb = v2.DatabaseAtV2(schema.newConnection().executor);
    await oldDb.customStatement(
      "INSERT INTO apps (package_name, name, version) VALUES ('me.efesser.flauncher', 'FLauncher', '0.0.1');",
    );
    await oldDb.customStatement(
      "INSERT INTO categories (id, name, \"order\") VALUES (1, 'Applications', 0);",
    );
    await oldDb.customStatement(
      "INSERT INTO apps_categories (category_id, app_package_name, \"order\") VALUES (1, 'me.efesser.flauncher', 0);",
    );
    await oldDb.close();

    final db = FLauncherDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 8);

    final app = await db.select(db.apps).getSingle();
    final category = await db.select(db.categories).getSingle();
    final appsCategory = await db.select(db.appsCategories).getSingle();
    expect(app.packageName, "me.efesser.flauncher");
    expect(app.name, "FLauncher");
    expect(app.version, "0.0.1");
    expect(app.hidden, false);
    expect(category.id, 1);
    expect(category.name, "Applications");
    expect(category.order, 0);
    expect(category.sort, CategorySort.manual);
    expect(category.type, CategoryType.grid);
    expect(category.columnsCount, 6);
    expect(category.rowHeight, 110);
    expect(appsCategory.appPackageName, "me.efesser.flauncher");
    expect(appsCategory.categoryId, 1);
    expect(appsCategory.order, 0);
    await db.close();
  });

  test("upgrade from v3 to v8", () async {
    final schema = await verifier.schemaAt(3);

    final oldDb = v3.DatabaseAtV3(schema.newConnection().executor);
    await oldDb.customStatement(
      "INSERT INTO apps (package_name, name, version) VALUES ('me.efesser.flauncher', 'FLauncher', '0.0.1');",
    );
    await oldDb.customStatement(
      "INSERT INTO categories (id, name, \"order\") VALUES (1, 'Applications', 0);",
    );
    await oldDb.customStatement(
      "INSERT INTO apps_categories (category_id, app_package_name, \"order\") VALUES (1, 'me.efesser.flauncher', 0);",
    );
    await oldDb.close();

    final db = FLauncherDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 8);

    final app = await db.select(db.apps).getSingle();
    final category = await db.select(db.categories).getSingle();
    final appsCategory = await db.select(db.appsCategories).getSingle();
    expect(app.packageName, "me.efesser.flauncher");
    expect(app.name, "FLauncher");
    expect(app.version, "0.0.1");
    expect(app.hidden, false);
    expect(category.id, 1);
    expect(category.name, "Applications");
    expect(category.order, 0);
    expect(category.sort, CategorySort.manual);
    expect(category.type, CategoryType.grid);
    expect(category.columnsCount, 6);
    expect(category.rowHeight, 110);
    expect(appsCategory.appPackageName, "me.efesser.flauncher");
    expect(appsCategory.categoryId, 1);
    expect(appsCategory.order, 0);
    await db.close();
  });

  test("upgrade from v4 to v8", () async {
    final schema = await verifier.schemaAt(4);

    final oldDb = v4.DatabaseAtV4(schema.newConnection().executor);
    await oldDb.customStatement(
      "INSERT INTO apps (package_name, name, version) VALUES ('me.efesser.flauncher', 'FLauncher', '0.0.1');",
    );
    await oldDb.customStatement(
      "INSERT INTO categories (id, name, type, \"order\") VALUES (1, 'Applications', 1, 0);",
    );
    await oldDb.customStatement(
      "INSERT INTO apps_categories (category_id, app_package_name, \"order\") VALUES (1, 'me.efesser.flauncher', 0);",
    );
    await oldDb.close();

    final db = FLauncherDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 8);

    final app = await db.select(db.apps).getSingle();
    final category = await db.select(db.categories).getSingle();
    final appsCategory = await db.select(db.appsCategories).getSingle();
    expect(app.packageName, "me.efesser.flauncher");
    expect(app.name, "FLauncher");
    expect(app.version, "0.0.1");
    expect(app.hidden, false);
    expect(category.id, 1);
    expect(category.name, "Applications");
    expect(category.order, 0);
    expect(category.sort, CategorySort.manual);
    expect(category.type, CategoryType.grid);
    expect(category.columnsCount, 6);
    expect(category.rowHeight, 110);
    expect(appsCategory.appPackageName, "me.efesser.flauncher");
    expect(appsCategory.categoryId, 1);
    expect(appsCategory.order, 0);
    await db.close();
  });
}
