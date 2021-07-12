# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2021_07_12_190126) do

  create_table "attributes", force: :cascade do |t|
    t.string "task"
    t.string "variable"
    t.string "value"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "demarche_id", null: false
    t.integer "dossier"
    t.index ["demarche_id"], name: "index_attributes_on_demarche_id"
    t.index ["dossier"], name: "index_attributes_on_dossier"
    t.index ["variable"], name: "index_attributes_on_variable"
  end

  create_table "checksums", force: :cascade do |t|
    t.integer "task_execution_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "filename"
    t.string "md5"
    t.index ["md5"], name: "index_checksums_on_md5"
    t.index ["task_execution_id", "filename"], name: "index_checksums_on_task_execution_id_and_filename"
    t.index ["task_execution_id"], name: "index_checksums_on_task_execution_id"
  end

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer "priority", default: 0, null: false
    t.integer "attempts", default: 0, null: false
    t.text "handler", null: false
    t.text "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string "locked_by"
    t.string "queue"
    t.datetime "created_at", precision: 6
    t.datetime "updated_at", precision: 6
    t.string "cron"
    t.index ["priority", "run_at"], name: "delayed_jobs_priority"
  end

  create_table "demarches", force: :cascade do |t|
    t.string "name"
    t.datetime "queried_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "demarches_users", id: false, force: :cascade do |t|
    t.integer "demarche_id", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "demarche_id"], name: "index_demarches_users_on_user_id_and_demarche_id"
  end

  create_table "job_tasks", force: :cascade do |t|
    t.integer "demarche_id", null: false
    t.string "name"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["demarche_id"], name: "index_job_tasks_on_demarche_id"
  end

  create_table "messages", force: :cascade do |t|
    t.string "message"
    t.integer "level"
    t.integer "task_execution_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["level"], name: "index_messages_on_level"
    t.index ["task_execution_id"], name: "index_messages_on_task_execution_id"
  end

  create_table "syncs", force: :cascade do |t|
    t.string "job"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "task_executions", force: :cascade do |t|
    t.integer "job_task_id", null: false
    t.integer "dossier"
    t.boolean "failed"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "version"
    t.datetime "discarded_at"
    t.index ["discarded_at"], name: "index_task_executions_on_discarded_at"
    t.index ["dossier"], name: "index_task_executions_on_dossier"
    t.index ["failed"], name: "index_task_executions_on_failed"
    t.index ["job_task_id"], name: "index_task_executions_on_job_task_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.boolean "is_admin"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  add_foreign_key "attributes", "demarches"
  add_foreign_key "checksums", "task_executions"
  add_foreign_key "job_tasks", "demarches"
  add_foreign_key "messages", "task_executions"
  add_foreign_key "task_executions", "job_tasks"
end
